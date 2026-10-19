cmake_minimum_required(VERSION 3.22.1)
project("swordnote_native" LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build types
set(CMAKE_BUILD_TYPE Release)
set(CMAKE_C_FLAGS "-O3 -DNDEBUG")
set(CMAKE_CXX_FLAGS "-O3 -DNDEBUG")

# Android-specific settings
if(ANDROID)
    set(CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION "clang")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")
endif()

# Output directory
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${ANDROID_ABI})

# =============================================================================
# LLAMA.CPP (Primary inference engine)
# =============================================================================
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp)

# =============================================================================
# SWORDNOTE JNI BRIDGE
# Mirrors CupCake's llama_jni.cpp pattern.
# Exposes: initModel, recognizeImage, generateText, release, isLoaded
# =============================================================================
add_library(swordnote_jni SHARED
    swordnote_jni.cpp
)

target_include_directories(swordnote_jni PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp/ggml/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party/llama.cpp/ggml/src
)

target_link_libraries(swordnote_jni PRIVATE
    llama
    ${CMAKE_DL_LIBS}
    ${CMAKE_THREAD_LIBS_INIT}
    log
    android
)

target_compile_options(swordnote_jni PRIVATE
    -O3
    -DNDEBUG
    -Wall -Wextra -Wpedantic
    -Wno-unused-parameter
    -DGGML_USE_ACCELERATE=OFF
    -DGGML_USE_METAL=OFF
    -DGGML_USE_CUDA=OFF
    -DGGML_USE_VULKAN=OFF
    -DGGML_USE_SYCL=OFF
    -DGGML_USE_RPC=OFF
    -DGGML_USE_OPENMP=OFF
    -DGGML_USE_THREADS=ON
)
