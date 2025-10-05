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

        tools = {
          aapt2 = {
            compile =
              pkgs.resholve.writeScript "aapt2-compile"
                {
                  inputs = [
                    pkgs.coreutils
                    "${android.androidsdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/"
                  ];
                  interpreter = "${pkgs.runtimeShell}";
                  execer = [
                    "cannot:${android.androidsdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/aapt2"
                  ];
                }
                ''
                  mkdir $dirName
                  cp $input $dirName/$fileName
                  aapt2 compile $dirName/$fileName -o .
                  mv $name $out
                '';
            link =
              pkgs.resholve.writeScript "aapt2-link"
                {
                  inputs = [
                    pkgs.coreutils
                    "${android.androidsdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/"
                  ];
                  interpreter = "${pkgs.runtimeShell}";
                  execer = [
                    "cannot:${android.androidsdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/aapt2"
                  ];
                }
                ''
                  mkdir $java
                  aapt2 link \
                    -o $out \
                    --manifest $manifest \
                    -I ${android.androidsdk}/libexec/android-sdk/platforms/android-${platformVersion}/android.jar \
                    --java $java \
                    $files
                '';
          };
        };

        sources = {
          src = pkgs.lib.fileset.fromSource ./src;
          res = pkgs.lib.fileset.fromSource ./res;
          manifest = ./AndroidManifest.xml;
        };

        env = {
          ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";

          buildInputs = [
            android.androidsdk
            pkgs.jdk
            pkgs.kotlin
            pkgs.zip
          ];

          packages = [
            tools.aapt2.compile
            tools.aapt2.link
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

          flats = map (
            f:
            let
              unpackedName = pkgs.lib.path.removePrefix sources.res._internalBase f;
              pathComponents = pkgs.lib.path.subpath.components unpackedName;
              dirName = builtins.elemAt pathComponents 0;
              fileName = builtins.elemAt pathComponents 1;
              isValues = pkgs.lib.strings.hasPrefix "values" dirName;
              newFileName =
                if isValues then (pkgs.lib.strings.removeSuffix ".xml" fileName) + ".arsc" else fileName;
              name = "${dirName}_${newFileName}.flat";
            in
            derivation {
              name = name;
              system = system;
              builder = tools.aapt2.compile;
              dirName = dirName;
              fileName = fileName;
              input = f;
            }
          ) (pkgs.lib.fileset.toList (sources.res));

          base-apk = derivation {
            name = "george.base.apk";
            system = system;
            outputs = [
              "out"
              "java"
            ];
            builder = tools.aapt2.link;
            manifest = sources.manifest;
            files = flats;
          };

          classes = pkgs.runCommand "george-classes" env ''
            mkdir $out
            javac \
              -classpath $ANDROID_HOME/platforms/android-${platformVersion}/android.jar \
              -d $out \
              $(find ${base-apk.java} -type f)
            kotlinc \
              -classpath $ANDROID_HOME/platforms/android-${platformVersion}/android.jar \
              -d $out \
              ${pkgs.lib.join " " (pkgs.lib.fileset.toList sources.src)} ${base-apk.java}
          '';

          dex = pkgs.runCommand "george.dex" env ''
            $ANDROID_HOME/build-tools/${buildToolsVersion}/d8 \
              $(find ${classes} -name "*.class") \
              ${pkgs.kotlin}/lib/kotlin-stdlib.jar
            mv classes.dex $out
          '';

          unaligned-apk = pkgs.runCommand "george.unaligned.apk" env ''
            cp --dereference --no-preserve=mode ${base-apk} $out
            cp --dereference --no-preserve=mode ${dex} classes.dex
            zip -u $out classes.dex
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
