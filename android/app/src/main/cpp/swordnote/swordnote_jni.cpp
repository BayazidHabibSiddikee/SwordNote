// SwordNote JNI Bridge — mirrors CupCake's llama_jni.cpp pattern.
//
// Exposes to Flutter/Dart via platform channel:
//   - initModel(path, nctx, nthreads, nbatch) → int
//   - recognizeImage(imagePath) → String (JSON)
//   - generateText(prompt) → int (async via callback)
//   - cancel() → void
//   - release() → void
//   - isLoaded() → bool
//   - getModelInfo() → String
//
// The model runs inference through llama.cpp with ARM64 NEON optimization.

#include <jni.h>
#include <string>
#include <vector>
#include <memory>
#include <thread>
#include <atomic>
#include <chrono>
#include <cstring>
#include <ctime>
#include <android/log.h>
#include "llama.h"

#define LOG_TAG "SwordNote"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// =============================================================================
// STATE
// =============================================================================
static llama_context* g_ctx = nullptr;
static llama_model* g_model = nullptr;
static std::vector<llama_token> g_tokens;
static std::vector<llama_token> g_cache_tokens;
static std::atomic<bool> g_is_generating{false};
static std::atomic<bool> g_should_stop{false};
static int g_n_batch = 512;

struct SamplingParams {
    float temp = 0.7f;
    float top_p = 0.9f;
    int top_k = 40;
    float repeat_penalty = 1.1f;
    int repeat_last_n = 64;
    int seed = -1;
    int max_tokens = 512;
};

static SamplingParams g_sampling_params;

// Callback for streaming tokens
static JavaVM* g_jvm = nullptr;
static jobject g_callback = nullptr;
static jmethodID g_on_token = nullptr;
static jmethodID g_on_complete = nullptr;
static jmethodID g_on_error = nullptr;

// =============================================================================
// UTILITIES
// =============================================================================
static bool is_valid_utf8(const std::string& str) {
    int expected = 0;
    for (unsigned char c : str) {
        if (expected == 0) {
            if ((c & 0x80) == 0) continue;
            else if ((c & 0xE0) == 0xC0) expected = 1;
            else if ((c & 0xF0) == 0xE0) expected = 2;
            else if ((c & 0xF8) == 0xF0) expected = 3;
            else return false;
        } else {
            if ((c & 0xC0) != 0x80) return false;
            expected--;
        }
    }
    return expected == 0;
}

static int common_prefix_len(const std::vector<llama_token>& a, const std::vector<llama_token>& b) {
    int n = 0;
    while (n < (int)a.size() && n < (int)b.size() && a[n] == b[n]) n++;
    return n;
}

static void emit_token(JNIEnv* env, const std::string& token) {
    if (!g_jvm || !g_callback || !g_on_token) return;
    JNIEnv* ejenv;
    if (g_jvm->AttachCurrentThread(&ejenv, nullptr) != JNI_OK) return;
    jstring jtoken = ejenv->NewStringUTF(token.c_str());
    ejenv->CallVoidMethod(g_callback, g_on_token, jtoken);
    ejenv->DeleteLocalRef(jtoken);
    g_jvm->DetachCurrentThread();
}

static void emit_complete(JNIEnv* env, int status) {
    if (!g_jvm || !g_callback || !g_on_complete) return;
    JNIEnv* ejenv;
    if (g_jvm->AttachCurrentThread(&ejenv, nullptr) != JNI_OK) return;
    ejenv->CallVoidMethod(g_callback, g_on_complete, status);
    g_jvm->DetachCurrentThread();
}

static void emit_error(JNIEnv* env, const std::string& error) {
    if (!g_jvm || !g_callback || !g_on_error) return;
    JNIEnv* ejenv;
    if (g_jvm->AttachCurrentThread(&ejenv, nullptr) != JNI_OK) return;
    jstring jerror = ejenv->NewStringUTF(error.c_str());
    ejenv->CallVoidMethod(g_callback, g_on_error, jerror);
    ejenv->DeleteLocalRef(jerror);
    g_jvm->DetachCurrentThread();
}

// =============================================================================
// JNI EXPORTS
// =============================================================================

extern "C" JNIEXPORT jint JNICALL
Java_com_swordnote_swordnote_ModelService_initModel(
    JNIEnv* env, jobject thiz,
    jstring model_path, jint n_ctx, jint n_threads, jint n_batch) {

    const char* path = env->GetStringUTFChars(model_path, nullptr);
    LOGI("Initializing model: %s", path);

    llama_backend_init();
    g_cache_tokens.clear();
    g_tokens.clear();
    g_n_batch = n_batch > 0 ? n_batch : 512;

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0; // CPU-only on Android
    model_params.use_mmap = true;
    model_params.use_mlock = false;

    g_model = llama_load_model_from_file(path, model_params);
    if (!g_model) {
        LOGE("Failed to load model: %s", path);
        env->ReleaseStringUTFChars(model_path, path);
        return -1;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = n_ctx > 0 ? (uint32_t)n_ctx : 2048;
    ctx_params.n_batch = g_n_batch;
    ctx_params.n_threads = n_threads > 0 ? n_threads : 4;
    ctx_params.n_threads_batch = ctx_params.n_threads;

    g_ctx = llama_new_context_with_model(g_model, ctx_params);
    if (!g_ctx) {
        LOGE("Failed to create context");
        llama_free_model(g_model);
        g_model = nullptr;
        env->ReleaseStringUTFChars(model_path, path);
        return -2;
    }

    LOGI("Model loaded successfully: %s (ctx=%d, threads=%d)", path, ctx_params.n_ctx, ctx_params.n_threads);
    env->ReleaseStringUTFChars(model_path, path);
    return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_swordnote_swordnote_ModelService_setCallback(
    JNIEnv* env, jobject thiz, jobject callback) {

    env->GetJavaVM(&g_jvm);
    if (g_callback) env->DeleteGlobalRef(g_callback);
    g_callback = env->NewGlobalRef(callback);
    jclass cls = env->GetObjectClass(g_callback);
    g_on_token = env->GetMethodID(cls, "onToken", "(Ljava/lang/String;)V");
    g_on_complete = env->GetMethodID(cls, "onComplete", "(I)V");
    g_on_error = env->GetMethodID(cls, "onError", "(Ljava/lang/String;)V");
    LOGI("Callback registered");
}

extern "C" JNIEXPORT void JNICALL
Java_com_swordnote_swordnote_ModelService_setSamplingParams(
    JNIEnv* env, jobject thiz,
    jfloat temp, jfloat top_p, jint top_k,
    jfloat repeat_penalty, jint repeat_last_n, jint seed, jint max_tokens) {

    g_sampling_params.temp = temp;
    g_sampling_params.top_p = top_p;
    g_sampling_params.top_k = top_k;
    g_sampling_params.repeat_penalty = repeat_penalty;
    g_sampling_params.repeat_last_n = repeat_last_n;
    g_sampling_params.seed = seed;
    g_sampling_params.max_tokens = max_tokens > 0 ? max_tokens : 512;
    LOGD("Sampling params set: temp=%.2f top_p=%.2f top_k=%d max_tokens=%d",
         temp, top_p, top_k, max_tokens);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_swordnote_swordnote_ModelService_generateText(
    JNIEnv* env, jobject thiz, jstring prompt) {

    if (!g_ctx || !g_model) {
        LOGE("Model not loaded");
        return -1;
    }

    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    std::string prompt_str_str(prompt_str);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    // Tokenize prompt
    g_tokens.clear();
    std::vector<llama_token> tokens;
    // Simple tokenization via llama_tokenize
    int n_tokens = llama_tokenize(g_model, prompt_str_str.c_str(), prompt_str_str.length(),
                                   nullptr, 0, true, true);
    if (n_tokens < 0) {
        LOGE("Tokenization failed: %d", n_tokens);
        return -2;
    }
    tokens.resize(n_tokens);
    n_tokens = llama_tokenize(g_model, prompt_str_str.c_str(), prompt_str_str.length(),
                               tokens.data(), tokens.size(), true, true);
    g_tokens.assign(tokens.begin(), tokens.begin() + n_tokens);

    // Run generation in background thread
    std::thread([=]() {
        JNIEnv* ejenv;
        if (g_jvm->AttachCurrentThread(&ejenv, nullptr) != JNI_OK) {
            g_is_generating = false;
            return;
        }

        g_is_generating = true;

        // Build sampler chain
        llama_sampler* smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
        llama_sampler_chain_add(smpl, llama_sampler_init_penalties(
            llama_n_vocab(g_model), llama_token_eos(g_model),
            -1, g_sampling_params.repeat_last_n,
            g_sampling_params.repeat_penalty > 1.0f ? g_sampling_params.repeat_penalty : 1.15f,
            0.25f, 0.10f, false, false));
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(g_sampling_params.top_k));
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(g_sampling_params.top_p, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(g_sampling_params.temp));
        const uint32_t seed = g_sampling_params.seed < 0
            ? (uint32_t)time(nullptr) : (uint32_t)g_sampling_params.seed;
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(seed));

        const int max_tokens = g_sampling_params.max_tokens > 0 ? g_sampling_params.max_tokens : 512;
        int generated = 0;

        // KV cache prefix reuse
        int n_match = common_prefix_len(g_cache_tokens, g_tokens);
        if (n_match >= (int)g_tokens.size()) n_match = (int)g_tokens.size() - 1;
        if (n_match > 0) {
            if (!llama_kv_cache_seq_rm(g_ctx, 0, n_match, -1)) {
                llama_kv_cache_clear(g_ctx);
                n_match = 0;
            }
        } else {
            llama_kv_cache_clear(g_ctx);
        }

        // Decode prompt
        bool decode_err = false;
        for (size_t i = (size_t)n_match; i < g_tokens.size(); i += g_n_batch) {
            int32_t chunk = std::min((int32_t)(g_tokens.size() - i), (int32_t)g_n_batch);
            if (llama_decode(g_ctx, llama_batch_get_one(g_tokens.data() + i, chunk))) {
                decode_err = true;
                break;
            }
        }
        if (decode_err) {
            g_cache_tokens.clear();
            emit_error(ejenv, "Failed to process prompt");
            g_is_generating = false;
            llama_sampler_free(smpl);
            g_jvm->DetachCurrentThread();
            return;
        }
        g_cache_tokens = g_tokens;

        // Generate tokens
        std::string utf8_buffer;
        std::string accumulated;
        while (generated < max_tokens && !g_should_stop.load()) {
            llama_token id = llama_sampler_sample(smpl, g_ctx, -1);

            if (llama_token_is_eog(g_model, id)) break;

            char buf[256];
            int len = llama_token_to_piece(g_model, id, buf, sizeof(buf), 0, true);
            if (len > 0) {
                std::string token_str(buf, len);
                accumulated.append(token_str);

                // Stop on turn boundaries
                if (accumulated.find("\nuser\n") != std::string::npos ||
                    accumulated.find("\nUser:") != std::string::npos) {
                    break;
                }

                utf8_buffer.append(token_str);
                if (is_valid_utf8(utf8_buffer)) {
                    emit_token(ejenv, utf8_buffer);
                    utf8_buffer.clear();
                }
            }

            g_tokens.push_back(id);
            if (llama_decode(g_ctx, llama_batch_get_one(&id, 1))) {
                emit_error(ejenv, "Decode failed");
                break;
            }
            generated++;
            llama_sampler_accept(smpl, id);
        }

        if (!utf8_buffer.empty()) {
            emit_token(ejenv, utf8_buffer);
        }

        llama_sampler_free(smpl);
        emit_complete(ejenv, 0);
        g_is_generating = false;
        g_jvm->DetachCurrentThread();
    }).detach();

    return 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_swordnote_swordnote_ModelService_cancel(JNIEnv* env, jobject thiz) {
    g_should_stop = true;
}

extern "C" JNIEXPORT void JNICALL
Java_com_swordnote_swordnote_ModelService_release(JNIEnv* env, jobject thiz) {
    g_cache_tokens.clear();
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_free_model(g_model); g_model = nullptr; }
    if (g_callback) { env->DeleteGlobalRef(g_callback); g_callback = nullptr; }
    llama_backend_free();
    LOGI("Model released");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_swordnote_swordnote_ModelService_isLoaded(JNIEnv* env, jobject thiz) {
    return g_ctx != nullptr && g_model != nullptr ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_swordnote_swordnote_ModelService_isGenerating(JNIEnv* env, jobject thiz) {
    return g_is_generating.load() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_swordnote_swordnote_ModelService_getModelInfo(JNIEnv* env, jobject thiz) {
    if (!g_model) return env->NewStringUTF("Not loaded");

    std::string info = "Model: Qwen2.5-0.5B\n";
    info += "Params: " + std::to_string(llama_model_n_params(g_model)) + "\n";
    info += "Vocab: " + std::to_string(llama_n_vocab(g_model)) + "\n";
    info += "Ctx: " + std::to_string(llama_n_ctx(g_ctx)) + "\n";
    info += "Embed: " + std::to_string(llama_n_embd(g_model)) + "\n";
    return env->NewStringUTF(info.c_str());
}

extern "C" JNIEXPORT jint JNICALL
Java_com_swordnote_swordnote_ModelService_analyzeImage(
    JNIEnv* env, jobject thiz, jstring image_path) {

    // TODO: Implement image analysis using the vision model.
    // This will call the Qwen2.5-VL model to analyze hand-drawn STEM content.
    // For now, return a stub indicating the feature is not yet implemented.
    LOGW("analyzeImage: stub — vision model integration pending (Phase 2)");
    return 0;
}
