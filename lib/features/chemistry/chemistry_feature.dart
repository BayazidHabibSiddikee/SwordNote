import 'package:flutter/material.dart';

/// Chemistry feature: molecule lookup and 3D rendering.
///
/// Phase 2 integration points:
/// - PubChem PUG REST API for name → SMILES
/// - RDKit (Python backend) for 3D coordinate generation
/// - 3Dmol.js or three_d_viewer Flutter package for rendering
class ChemistryFeature {
  /// Look up a molecule by name and return its SMILES string.
  Future<String> nameToSmiles(String name) async {
    // TODO: Call PubChem API
    // Example: https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$name/property/IsomericSMILES/JSON
    throw UnimplementedError('PubChem integration pending');
  }

  /// Detect if the given text contains a chemistry term.
  static bool isChemistryContext(String text) {
    final chemTerms = {
      'benzene', 'caffeine', 'water', 'h2o', 'co2', 'oh',
      'atom', 'molecule', 'bond', 'ring', 'carbon', 'oxygen',
      'nitrogen', 'hydrogen', 'electronegativity', 'photon',
    };
    return chemTerms.any((term) => text.toLowerCase().contains(term));
  }
}
