{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          system = system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };

        platformVersion = "36";
        buildToolsVersion = "36.0.0";

        android = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ platformVersion ];
          buildToolsVersions = [ buildToolsVersion ];
        };

        src = pkgs.lib.cleanSource ./.;

        env = {
          ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";

          buildInputs = [
            android.androidsdk
            pkgs.jdk
            pkgs.kotlin
          ];

        };
      in
      {
        formatter =
          pkgs.resholve.writeScriptBin "formatter"
            {
              inputs = [
                pkgs.findutils
                pkgs.libxml2
                pkgs.nixfmt-rfc-style
                pkgs.ktfmt
              ];
              interpreter = "${pkgs.runtimeShell}";
              execer = [
                "cannot:${pkgs.nixfmt-rfc-style}/bin/nixfmt"
                "cannot:${pkgs.ktfmt}/bin/ktfmt"
              ];
            }
            ''
              find . -name "*.xml" -type f -exec xmllint --output '{}' --format '{}' \;
              find . -name "*.nix" -type f -exec nixfmt '{}' \;
              find . -name "*.kt" -type f -exec ktfmt '{}' \;
            '';

        devShells.default = pkgs.mkShell env;

        packages = rec {

          gen = pkgs.runCommand "george-gen" env ''
            mkdir $out
            $ANDROID_HOME/build-tools/${buildToolsVersion}/aapt package -f -m \
              -J $out \
              -S ${self.sourceInfo}/res \
              -M ${self.sourceInfo}/AndroidManifest.xml \
              -I $ANDROID_HOME/platforms/android-${platformVersion}/android.jar
            javac \
              -classpath $ANDROID_HOME/platforms/android-${platformVersion}/android.jar \
              -d $out \
              $out/majkrzak/george/R.java
          '';

          cls = pkgs.runCommand "george-cls" env ''
            mkdir $out
            kotlinc \
              -classpath $ANDROID_HOME/platforms/android-${platformVersion}/android.jar:${gen} \
              -d $out \
              ${src}
          '';

          dex = pkgs.runCommand "george.dex" env ''
            $ANDROID_HOME/build-tools/${buildToolsVersion}/d8 \
              $(find ${gen} ${cls} -name "*.class") \
              ${pkgs.kotlin}/lib/kotlin-stdlib.jar
            mv classes.dex $out
          '';

          unaligned-apk = pkgs.runCommand "george.unaligned.apk" env ''
            mkdir apk
            ln -s ${dex} apk/classes.dex
            $ANDROID_HOME/build-tools/${buildToolsVersion}/aapt package \
              -M ${self.sourceInfo}/AndroidManifest.xml \
              -S ${self.sourceInfo}/res \
              -I $ANDROID_HOME/platforms/android-${platformVersion}/android.jar \
              -F $out \
            apk
          '';

          unsigned-apk = pkgs.runCommand "george.unsigned.apk" env ''
            $ANDROID_HOME/build-tools/${buildToolsVersion}/zipalign \
              -f -p 4 \
              ${unaligned-apk} \
              $out
          '';

          jks = pkgs.runCommand "george.jks" env ''
            keytool -genkeypair -keystore $out -alias androidkey \
              -dname "CN=george" \
              -validity 10000 -keyalg RSA -keysize 2048 \
              -storepass android -keypass android
          '';

          apk = pkgs.runCommand "george.apk" env ''
            $ANDROID_HOME/build-tools/${buildToolsVersion}/apksigner sign \
              --ks ${jks} \
              --ks-key-alias androidkey \
              --ks-pass pass:android \
              --key-pass pass:android \
              --out $out \
              ${unsigned-apk}
          '';

          default = apk;
        };
      }
    );

}
