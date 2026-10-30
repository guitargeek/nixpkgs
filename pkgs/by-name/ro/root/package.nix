{
  stdenv,
  lib,
  applyPatches,
  blas,
  callPackage,
  civetweb,
  curl,
  fetchFromGitHub,
  fetchzip,
  makeWrapper,
  writeText,
  apple-sdk,
  cmake,
  coreutils,
  git,
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
  version = "6.42.00";

  passthru = {
    tests = import ./tests { inherit callPackage; };
  };

  src = fetchFromGitHub {
    owner = "root-project";
    repo = "root";
    tag = "v6-42-00-rc1";
    hash = "sha256-IVnOl/E9YjhARabCFMEBnfsKY/QZnsJp/ryYdwZIyxs=";
  };

  # Since ROOT 6.42, the openui5 runtime distribution is no longer bundled
  # with the sources but downloaded at configure time. The runtime
  # distribution is a build artifact that is only available as a release
  # asset, not as a git tag. Make sure that the version matches the one in the
  # ROOT build files!
  # https://github.com/root-project/root/blob/master/builtins/openui5/CMakeLists.txt
  openui5_version = "1.152.0";
  openui5_src = fetchzip {
    name = "openui5-runtime-${finalAttrs.openui5_version}";
    url = "https://github.com/UI5/openui5/releases/download/${finalAttrs.openui5_version}/openui5-runtime-${finalAttrs.openui5_version}.zip";
    hash = "sha256-M6Hv5WGDSUpp+su+y6mNfhozJ4CJf18UbKYT7uGY5WQ=";
    # The zip has no single top-level directory
    stripRoot = false;
  };

  # mathjax for TMathText rendering in JSROOT. The tarball that ROOT would
  # download from LCG is identical to the GitHub release. Make sure that the
  # version matches the one in the ROOT build files!
  # https://github.com/root-project/root/blob/master/builtins/mathjax/CMakeLists.txt
  mathjax_src = fetchFromGitHub {
    owner = "mathjax";
    repo = "MathJax";
    tag = "3.2.0";
    hash = "sha256-sFWdSVktoDBiOgvWv8fZol2GGXbORjf6ieNmd5u/o0g=";
  };

  clad_src = applyPatches {
    src = fetchFromGitHub {
      owner = "vgvassilev";
      repo = "clad";
      # Make sure that this is the same tag as in the ROOT build files!
      # https://github.com/root-project/root/blob/master/interpreter/cling/tools/plugins/clad/CMakeLists.txt#L97
      tag = "v2.5";
      hash = "sha256-NIU2Sp8eBMpQ+1bSdykVnJJKTo8KS/2hBVKPAg1MwGg=";
    };
    # ROOT would apply these patches itself at build time with git, which
    # doesn't work on the read-only source in the Nix store. Make sure that
    # these are the same patches as in the ROOT build files!
    # https://github.com/root-project/root/blob/master/interpreter/cling/tools/plugins/clad/CMakeLists.txt#L102
    patches = [
      "${finalAttrs.src}/interpreter/cling/tools/plugins/clad/patches/lld_lookup_no_default_path.patch"
    ];
  };

  # ROOT requires a patched version of clang
  clang = (callPackage ./clang-root.nix { });

  patches = [
    # Adds the OPENUI5_SOURCE_DIR CMake variable, analogous to CLAD_SOURCE_DIR
    ./Allow-using-an-already-unpacked-openui5-runtime-distribution.patch
    # With builtin_mathjax=ON, ROOT only unpacks mathjax into the build tree
    # but never installs it next to JSROOT
    ./Install-the-builtin-mathjax-distribution.patch
    # Adds the MATHJAX_SOURCE_DIR CMake variable, analogous to CLAD_SOURCE_DIR
    ./Allow-using-an-already-unpacked-mathjax-distribution.patch
    # The clad sources are already patched (see clad_src above)
    ./Do-not-patch-clad-when-an-external-clad-source-directory-is-used.patch
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
    git
  ];
  propagatedBuildInputs = [
    nlohmann_json # link interface of target "ROOT::ROOTEve"
  ];
  buildInputs = [
    finalAttrs.clang
    blas
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

  preConfigure = ''
    # Remove the bundled third-party sources that are not needed, to make sure
    # that the system versions are used. The ones that are kept are either
    # hard-coded builtins without a system alternative, or the ones enabled
    # explicitly in cmakeFlags.
    for path in builtins/*; do
      case "$(basename "$path")" in
        bvh|CDT|clib|csg|exprtk|glad|libAfterImage|libmathtext|libtextinput|mathjax|mixmax|openui5|optionparser|rendercore|x3d|xvertext|zip) ;;
        *) rm -rf "$path" ;;
      esac
    done

    # Make sure that nothing gets downloaded at build time
    substituteInPlace cmake/modules/SearchInstalledSoftware.cmake \
      --replace-fail 'set(lcgpackages ' '#set(lcgpackages '

    patchShebangs cmake/unix/
  ''
  +
    lib.optionalString
      (stdenv.hostPlatform.isDarwin && lib.versionAtLeast stdenv.hostPlatform.darwinMinVersion "11")
      ''
        MACOSX_DEPLOYMENT_TARGET=10.16
      '';

  cmakeFlags = [
    "-DCLAD_SOURCE_DIR=${finalAttrs.clad_src}"
    "-DClang_DIR=${finalAttrs.clang}/lib/cmake/clang"
    "-Dbuiltin_clang=OFF"
    "-Dbuiltin_llvm=OFF"
    "-Dbuiltin_openui5=ON"
    "-Dbuiltin_mathjax=ON"
    "-DOPENUI5_SOURCE_DIR=${finalAttrs.openui5_src}"
    "-DMATHJAX_SOURCE_DIR=${finalAttrs.mathjax_src}"
    "-Dfail-on-missing=ON"
    "-Dfftw3=ON"
    "-Dfitsio=OFF"
    "-Dmathmore=ON"
    "-Dsqlite=OFF"
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
    platforms = lib.platforms.unix;
    maintainers = [
      lib.maintainers.guitargeek
      lib.maintainers.veprbl
    ];
    license = lib.licenses.lgpl21;
  };
})
