{ lib
, stdenv
, fetchFromGitHub
, kernel
}:

stdenv.mkDerivation rec {
  pname = "amdxdna";
  version = "2.21.75";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "xdna-driver";
    rev = version;
    hash = "sha256-pc9ou88iNAQpjcFvv9NluF8ag87v1KA/14bgfKWe0NE=";
    # XRT submodule not needed for kernel module
  };

  sourceRoot = "${src.name}/src";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  hardeningDisable = [ "pic" "format" ];

  KERNEL_SRC = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  # The configure_kernel.sh probes kernel features via try_compile.
  # Its initial check looks for $KERNEL_SRC/include/linux which in Nix
  # is behind a source symlink. We patch the check and then run it.
  postPatch = ''
    sed -i 's|$KERNEL_SRC/include/linux|$KERNEL_SRC/source/include/linux|' \
      driver/tools/configure_kernel.sh

    # Remove -Werror from Kbuild
    sed -i '/-Werror/d' driver/amdxdna/Kbuild
  '';

  preBuild = ''
    export KERNEL_VER=${kernel.modDirVersion}

    # Run the feature detection script (generates driver/amdxdna/config_kernel.h)
    bash driver/tools/configure_kernel.sh
  '';

  buildPhase = ''
    runHook preBuild

    make -C $KERNEL_SRC \
      M=$PWD/driver/amdxdna \
      CFLAGS_MODULE="-DAMDXDNA_DEVEL -DMODULE_VER_STR='\"${version}\"'" \
      OFT_CONFIG_AMDXDNA_PCI=y \
      OFT_CONFIG_AMDXDNA_OF=n \
      modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    make -C $KERNEL_SRC \
      M=$PWD/driver/amdxdna \
      INSTALL_MOD_PATH=$out \
      modules_install

    runHook postInstall
  '';

  meta = with lib; {
    description = "Out-of-tree AMD XDNA kernel driver for Ryzen AI NPUs";
    homepage = "https://github.com/amd/xdna-driver";
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
