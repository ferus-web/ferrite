with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    pkg-config
    simdutf
    nph
  ];

  LD_LIBRARY_PATH = lib.makeLibraryPath [
    simdutf
  ];
}
