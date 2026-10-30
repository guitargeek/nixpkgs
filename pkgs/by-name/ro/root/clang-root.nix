{
  stdenv,
  lib,
  fetchgit,
  apple-sdk,
  cmake,
  git,
  llvm_22,
  pkg-config,
  python3,
}:

stdenv.mkDerivation rec {
  pname = "clang-root";
  version = "22-20261028-01";

  src = fetchgit {
    url = "https://github.com/root-project/llvm-project";
    tag = "ROOT-llvm${version}";
    hash = "sha256-F8VfCbZ9vCURlqRXYYZQYALDq5P8S2G1D/S1fmyLDPw=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    git
  ];
  buildInputs = [
    llvm_22
    python3
  ];

  preConfigure = ''
    cd clang
  '';

  cmakeFlags = [
    "-DCLANG_BUILD_TOOLS=OFF"
    "-DCLANG_ENABLE_ARCMT=OFF"
    "-DCLANG_ENABLE_STATIC_ANALYZER=OFF"
    "-DCLANG_LINK_CLANG_DYLIB=OFF"
    "-DC_INCLUDE_DIRS=${lib.getDev stdenv.cc.libc}/include"
    "-DLLVM_INCLUDE_TESTS=OFF"
    "-DLLVM_LINK_LLVM_DYLIB=OFF"
    "-DLLVM_MAIN_SRC_DIR=${llvm_22.src}"
  ]
  ++ (
    if stdenv.hostPlatform.isDarwin then
      [ "-DC_INCLUDE_DIRS=${apple-sdk.sdkroot}/usr/include" ]
    else
      lib.optional (stdenv.cc.libc != null) "-DC_INCLUDE_DIRS=${lib.getDev stdenv.cc.libc}/include"
  );
}
