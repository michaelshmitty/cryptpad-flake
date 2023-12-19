{ lib, buildNpmPackage, fetchFromGitHub, nodejs, nixosTests }:

buildNpmPackage rec {
  pname = "cryptpad";
  version = "5.5.0";

  src = fetchFromGitHub {
    owner = "cryptpad";
    repo = pname;
    rev = version;
    hash = "sha256-EBFO/9zjlphkOEO80QhB3iB7TeoxO6+aThHY5n0aaG4=";
  };

  npmDepsHash = "sha256-kMpagy38UpQpQvfsEnNMJYUtO1XfpeEnvRD6TeValTc=";

  # The Cryptpad build tries to write to the cache
  makeCacheWritable = true;

  # npm install seems to drop some directories generated during the build. Just copy instead.
  dontNpmInstall = true;
  installPhase = ''
    out_cryptpad="$out/lib/node_modules/cryptpad"

    mkdir -p "$out_cryptpad"
    cp -r . "$out_cryptpad"

    # cryptpad assumes it runs in the source directory and also outputs
    # its state files there, which is not exactly great for us.
    # There are relative paths everywhere so just substituting source paths
    # is difficult and will likely break on a future update, instead we
    # can either make links we want to source files locally when we run,
    # or make links to a likely place where we'll want to store files
    # (e.g. /var/lib/cryptpad) for data directories in the source dir.
    # The later looks more fragile, so we have the wrapper create our links
    # instead.
    # Note 'customize' is meant to be overridable, so only overwrite it if it
    # was a symlink.
    makeWrapper ${nodejs}/bin/node $out/bin/cryptpad \
      --add-flags "$out_cryptpad/server.js" \
      --run "for d in customize.dist lib www; do ln -sf $out_cryptpad/\$d .; done" \
      --run "if ! [ -e customize ] || [ -L customize ]; then ln -sf $out_cryptpad/customize .; fi"

    # It also somehow expects node_modules to be available through www/components,
    # so we make that one link.
    ln -s ../node_modules "$out_cryptpad/www/components"
  '';

  passthru.tests.cryptpad = nixosTests.cryptpad;

  meta = with lib; {
    description = "Collaborative office suite, end-to-end encrypted and open-source.";
    homepage = "https://cryptpad.org/";
    license = licenses.agpl3;
    maintainers = with maintainers; [ martinetd michaelshmitty ];
  };
}
