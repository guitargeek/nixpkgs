{
  lib,
  stdenvNoCC,
  fetchzip,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jsroot";
  version = "7.12.0";

  # The release tarball is a build artifact (bundled and minified modules)
  # that is only available as a release asset, not as a git tag.
  src = fetchzip {
    name = "jsroot-${finalAttrs.version}";
    url = "https://github.com/root-project/jsroot/releases/download/${finalAttrs.version}/JsRoot${
      lib.replaceStrings [ "." ] [ "" ] finalAttrs.version
    }.tar.gz";
    hash = "sha256-XyzlLVuqn4fnNutbDbFjYmGThoCpQfrBITwg3FnUHFs=";
    # The tarball has no single top-level directory
    stripRoot = false;
  };

  # When used from ROOT web widgets, JSROOT loads mathjax from the "mathjax"
  # subdirectory next to its own sources (see modules/base/latex.mjs). JSROOT
  # expects this specific mathjax version, which is also what it falls back to
  # from the CDN.
  mathjax_src = fetchFromGitHub {
    owner = "mathjax";
    repo = "MathJax";
    tag = "3.2.0";
    hash = "sha256-sFWdSVktoDBiOgvWv8fZol2GGXbORjf6ieNmd5u/o0g=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/jsroot
    cp -r . $out/share/jsroot
    ln -s ${finalAttrs.mathjax_src} $out/share/jsroot/mathjax

    runHook postInstall
  '';

  meta = {
    description = "JavaScript ROOT, the web-based part of the ROOT data analysis framework";
    homepage = "https://root.cern/js/";
    changelog = "https://github.com/root-project/jsroot/blob/${finalAttrs.version}/changes.md";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.guitargeek ];
    platforms = lib.platforms.all;
  };
})
