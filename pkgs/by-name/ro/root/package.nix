{
  stdenv,
  lib,
  applyPatches,
  blas,
  callPackage,
  cfitsio,
  civetweb,
  curl,
  fetchFromGitHub,
  fetchurl,
  linkFarm,
  makeWrapper,
  apple-sdk,
  cmake,
  coreutils,
  davix,
  fftw,
  ftgl,
  gl2ps,
  gnugrep,
  gnused,
  gsl,
  libGLU,
  libGL,
  libxcrypt,
  libxml2,
  llvm_22,
  lsof,
  lz4,
  libxpm,
  libxft,
  libxext,
  libx11,
  xz,
  man,
  openssl,
  pcre2,
  nlohmann_json,
  pkg-config,
  procps,
  python3,
  sqlite,
  which,
  xxhash,
  zlib,
  zstd,
  giflib,
  libjpeg,
  libtiff,
  libpng,
  patchRcPathCsh,
  patchRcPathFish,
  patchRcPathPosix,
  onetbb,
  xrootd,
  freetype,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "root";
  # The last tag reachable from the master branch, which the PR is based on
  version = "6.41.99-unstable-2026-10-30";

  passthru = {
    tests = import ./tests { inherit callPackage; } // {
      # The Python package runs the import checks for the PyROOT bindings
      pyroot = python3.pkgs.root;
    };
  };

  # https://github.com/root-project/root/pull/23877
  src = fetchFromGitHub {
    owner = "linev";
    repo = "root";
    rev = "cdb07801f9c361e8c5dab4c016851c99df18ed81";
    hash = "sha256-fS5rEJCNtzaxFnHSRkR5IHYAGAwyoE8UuTAFOOuuSKE=";
  };

  # Archives of the packages that ROOT would otherwise download at build time
  # for the builtin_jsroot, builtin_openui5 and builtin_mathjax options. The
  # file names and hashes must match the ones in the ROOT build files!
  # https://github.com/root-project/root/tree/master/builtins
  builtin_downloads = linkFarm "root-builtin-downloads" [
    {
      name = "JsRoot7120.tar.gz";
      path = fetchurl {
        url = "https://github.com/root-project/jsroot/releases/download/7.12.0/JsRoot7120.tar.gz";
        hash = "sha256-5dgoiHUL2nAJCsS/81VzQAA3LJg6Pv8R1n76CfMNSwY=";
      };
    }
    {
      name = "openui5-runtime-1.152.0.zip";
      path = fetchurl {
        url = "https://github.com/UI5/openui5/releases/download/1.152.0/openui5-runtime-1.152.0.zip";
        hash = "sha256-SIICPUdg7UwgYC423Rg7AqU4/H6Lv9pge24lvRy7zbE=";
      };
    }
    {
      name = "mathjax-3.2.0.tar.gz";
      path = fetchurl {
        url = "https://github.com/mathjax/MathJax/archive/refs/tags/3.2.0.tar.gz";
        hash = "sha256-aEfxz92YCvvjG0ZkdNowGlarhZpn2ANUQrBS3UrC+gM=";
      };
    }
  ];

  clad_src = applyPatches {
    src = fetchFromGitHub {
      owner = "vgvassilev";
      repo = "clad";
      # Make sure that this is the same tag as in the ROOT build files!
      # https://github.com/root-project/root/blob/master/interpreter/cling/tools/plugins/clad/CMakeLists.txt#L97
      tag = "v2.5";
      hash = "sha256-NIU2Sp8eBMpQ+1bSdykVnJJKTo8KS/2hBVKPAg1MwGg=";
    };
    # ROOT applies these patches to its own clad download, but not to an
    # external clad source directory. Make sure that these are the same
    # patches as in the ROOT build files!
    # https://github.com/root-project/root/blob/master/interpreter/cling/tools/plugins/clad/CMakeLists.txt#L102
    patches = [
      "${finalAttrs.src}/interpreter/cling/tools/plugins/clad/patches/lld_lookup_no_default_path.patch"
    ];
  };

  # ROOT requires a patched version of clang
  clang = (callPackage ./clang-root.nix { });

  patches = [
    # Adds the ROOT_DOWNLOAD_DIR CMake variable, see builtin_downloads above
    ./Allow-using-pre-downloaded-archives-for-the-builtin-packages.patch
    # Configuration error in the PR branch, see the patch
    ./Fix-the-install-rule-for-the-builtin-openui5-distribution.patch
    # compiledata.sh is otherwise run via its /usr/bin/env shebang
    ./Run-compiledata.sh-with-bash-explicitly.patch
    # Since ROOT 6.42, rootcling drops all include paths that CMake reports as
    # compiler default include directories, assuming that cling will find
    # them on its own. See:
    # https://github.com/root-project/root/commit/b304aa5942542317442cea603dd57c9bc5345ff2
    # With the Nix compiler wrapper, the include directories of all
    # dependencies show up as compiler defaults, but cling only knows about
    # the ones of the compiler and the C library.
    ./Only-report-include-directories-known-to-cling-as-compiler-defaults.patch
  ];

  nativeBuildInputs = [
    makeWrapper
    cmake
    pkg-config
  ];
  propagatedBuildInputs = [
    nlohmann_json # link interface of target "ROOT::ROOTEve"
  ];
  buildInputs = [
    finalAttrs.clang
    blas
    cfitsio
    (civetweb.override {
      # ROOT requires civetweb with websocket, zlib and unix domain socket support
      withWebSockets = true;
      withZlib = true;
      withUnixSockets = true;
    })
    curl
    davix
    fftw
    ftgl
    giflib
    gl2ps
    gsl
    libjpeg
    libpng
    libtiff
    libxcrypt
    libxml2
    llvm_22
    lz4
    openssl
    patchRcPathCsh
    patchRcPathFish
    patchRcPathPosix
    pcre2
    python3
    sqlite
    onetbb
    xrootd
    xxhash
    xz
    zlib
    zstd
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    apple-sdk.privateFrameworksHook
    freetype
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    libGLU
    libGL
    libx11
    libxpm
    libxft
    libxext
  ];

  cmakeFlags = [
    "-DCLAD_SOURCE_DIR=${finalAttrs.clad_src}"
    "-DClang_DIR=${finalAttrs.clang}/lib/cmake/clang"
    "-Dbuiltin_clang=OFF"
    "-Dbuiltin_llvm=OFF"
    "-Dbuiltin_jsroot=ON"
    "-Dbuiltin_mathjax=ON"
    "-Dbuiltin_openui5=ON"
    "-DROOT_DOWNLOAD_DIR=${finalAttrs.builtin_downloads}"
    "-Dfail-on-missing=ON"
    "-Dfftw3=ON"
    "-Dmathmore=ON"
    "-Dvdt=OFF"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # fatal error: module map file '/nix/store/<hash>-Libsystem-osx-10.12.6/include/module.modulemap' not found
    # fatal error: could not build module '_Builtin_intrinsics'
    "-Druntime_cxxmodules=OFF"
  ];

  postInstall = ''
    for prog in rooteventselector rootmv rootprint rootslimtree; do
      wrapProgram "$out/bin/$prog" \
        --set PYTHONPATH "$out/lib"
    done

    # Make ldd and sed available to the ROOT executable by prefixing PATH.
    wrapProgram "$out/bin/root" \
      --prefix PATH : "${
        lib.makeBinPath [
          gnused # sed
          stdenv.cc # c++ ld etc.
          stdenv.cc.libc # ldd
        ]
      }"

    # Patch thisroot.{sh,csh,fish}

    # The main target of `thisroot.sh` is "bash-like shells",
    # but it also need to support Bash-less POSIX shell like dash,
    # as they are mentioned in `thisroot.sh`.

    patchRcPathPosix "$out/bin/thisroot.sh" "${
      lib.makeBinPath [
        coreutils # dirname tail
        gnugrep # grep
        gnused # sed
        lsof # lsof
        man # manpath
        procps # ps
        which # which
      ]
    }"
    patchRcPathCsh "$out/bin/thisroot.csh" "${
      lib.makeBinPath [
        coreutils
        gnugrep
        gnused
        lsof # lsof
        man
        which
      ]
    }"
    patchRcPathFish "$out/bin/thisroot.fish" "${
      lib.makeBinPath [
        coreutils
        man
        which
      ]
    }"
  '';

  # To use the debug information on the fly (without installation)
  # add the outPath of root.debug into NIX_DEBUG_INFO_DIRS (in PATH-like format)
  # and make sure that gdb from Nixpkgs can be found in PATH.
  #
  # Darwin currently fails to support it (#203380)
  # we set it to true hoping to benefit from the future fix.
  # Before that, please make sure if root.debug exists before using it.
  separateDebugInfo = true;

  setupHook = ./setup-hook.sh;

  meta = {
    homepage = "https://root.cern/";
    description = "Data analysis framework";
    changelog =
      if lib.hasInfix "-unstable-" finalAttrs.version then
        "https://root.cern/doc/master/release-notes.html"
      else
        "https://root.cern/doc/v${lib.versions.major finalAttrs.version}${lib.versions.minor finalAttrs.version}/release-notes.html";
    platforms = lib.platforms.unix;
    maintainers = [
      lib.maintainers.guitargeek
      lib.maintainers.veprbl
    ];
    license = lib.licenses.lgpl21Plus;
    mainProgram = "root";
  };
})
