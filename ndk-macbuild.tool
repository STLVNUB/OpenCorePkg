#!/bin/bash

export GCC5_BIN="$HOME/src/opt/local/cross/bin/x86_64-clover-linux-gnu-"
export NASM_PREFIX="$HOME/src/opt/local/bin/"
export TOOLCHAIN=GCC5 #XCODE5
export TARGETARCH=X64
export BUILDTARGET=RELEASE
export BUILDTHREADS=$(( NUMBER_OF_CPUS + 1 ))
export WORKSPACE=${WORKSPACE:-}
name=$(basename "$0")
dir=$(dirname "$0")
declare BUILDDIR=$(dirname "$0")
if [ -f "/usr/local/bin/ocb" ]; then
    echo "OK OpenCore Builder link installed"
    LPATH=$(readlink -n "$0" )
    declare -r BUILDDIR=$(dirname "${LPATH}")
else
	isLink=$(ls -l /usr/local/bin/ocb)
   	unlink /usr/local/bin/ocb
fi
if [ ! -f "/usr/local/bin/ocb" ]; then
    echo "link /usr/local/bin/ocb to $0"
    echo "then type ocb to run ;)"
    echo "ln -s "$dir/$name" /usr/local/bin/ocb"
    sudo ln -s "${dir}/${name}" /usr/local/bin/ocb
fi
cd "$BUILDDIR"
if [ $TOOLCHAIN == GCC5 ] && [ ! -d $GCC%_BIN ]; then
	./build_gcc9.sh
	wait
fi	
echo "Building with $TOOLCHAIN"
prompt() {
  echo "$1"
  if [ "$FORCE_INSTALL" != "1" ]; then
    read -p "Enter [Y]es to continue: " v
    if [ "$v" != "Y" ] && [ "$v" != "y" ]; then
      exit 1
    fi
  fi
}

updaterepo() {
  echo $2
  if [ ! -d "$2" ]; then
    git clone "$1" -b "$3" --depth=1 "$2" || exit 1
    if [ $2 == edk2 ]; then
	    cd edk2
    	touch edk2.ready
    	cd ..
    fi
  fi
  pushd "$2" >/dev/null
  git pull
  if [ "$2" != "edk2" ]; then
    sym=$(find . -not -type d -exec file "{}" ";" | grep CRLF)
    if [ "${sym}" != "" ]; then
      echo "Repository $1 named $2 contains CRLF line endings"
      exit 1
    fi
  fi
  popd >/dev/null
}

package() {
  if [ ! -d "$1" ]; then
    echo "Missing package directory"
    exit 1
  fi

  local ver=$(cat Include/OpenCore.h | grep OPEN_CORE_VERSION | sed 's/.*"\(.*\)".*/\1/' | grep -E '^[0-9.]+$')
  if [ "$ver" = "" ]; then
    echo "Invalid version $ver"
  fi

  selfdir=$(pwd)
  pushd "$1" || exit 1
  rm -rf tmp || exit 1
  mkdir -p tmp/EFI || exit 1
  mkdir -p tmp/EFI/OC || exit 1
  mkdir -p tmp/EFI/OC/ACPI || exit 1
  mkdir -p tmp/EFI/OC/Drivers || exit 1
  mkdir -p tmp/EFI/OC/Kexts || exit 1
  mkdir -p tmp/EFI/OC/Tools || exit 1
  mkdir -p tmp/EFI/BOOT || exit 1
  mkdir -p tmp/Docs/AcpiSamples || exit 1
  mkdir -p tmp/Utilities || exit 1
  cp OpenCore.efi tmp/EFI/OC/ || exit 1
  cp BOOTx64.efi tmp/EFI/BOOT/ || exit 1
  cp "${selfdir}/Docs/Configuration.pdf" tmp/Docs/ || exit 1
  cp "${selfdir}/Docs/Differences/Differences.pdf" tmp/Docs/ || exit 1
  cp "${selfdir}/Docs/Sample.plist" tmp/Docs/ || exit 1
  cp "${selfdir}/Docs/SampleFull.plist" tmp/Docs/ || exit 1
  cp "${selfdir}/Changelog.md" tmp/Docs/ || exit 1
  cp -r "${selfdir}/Docs/AcpiSamples/" tmp/Docs/AcpiSamples/ || exit 1
  cp -r "${selfdir}/edk2/OcSupportPkg/Utilities/BootInstall" tmp/Utilities/ || exit 1
  cp -r "${selfdir}/edk2/OcSupportPkg/Utilities/CreateVault" tmp/Utilities/ || exit 1
  cp -r "${selfdir}/edk2/OcSupportPkg/Utilities/LogoutHook" tmp/Utilities/ || exit 1
  pushd tmp || exit 1
  zip -qry -FS ../"OpenCore-${ver}-${2}.zip" * || exit 1
  popd || exit 1
  rm -rf tmp || exit 1
  popd || exit 1
}

if [ "$BUILDDIR" != "$(printf "%s\n" $BUILDDIR)" ]; then
  echo "EDK2 build system may still fail to support directories with spaces!"
  exit 1
fi

if [ "$(which clang)" = "" ] || [ "$(which git)" = "" ] || [ "$(clang -v 2>&1 | grep "no developer")" != "" ] || [ "$(git -v 2>&1 | grep "no developer")" != "" ]; then
  echo "Missing Xcode tools, please install them!"
  exit 1
fi

if [ "$(nasm -v)" = "" ] || [ "$(nasm -v | grep Apple)" != "" ]; then
  echo "Missing or incompatible nasm!"
  echo "Download the latest nasm from http://www.nasm.us/pub/nasm/releasebuilds/"
  prompt "Install last tested version automatically?"
  pushd /tmp >/dev/null
  rm -rf nasm-mac64.zip
  curl -OL "https://github.com/acidanthera/ocbuild/raw/master/external/nasm-mac64.zip" || exit 1
  nasmzip=$(cat nasm-mac64.zip)
  rm -rf nasm-*
  curl -OL "https://github.com/acidanthera/ocbuild/raw/master/external/${nasmzip}" || exit 1
  unzip -q "${nasmzip}" nasm*/nasm nasm*/ndisasm || exit 1
  sudo mkdir -p /usr/local/bin || exit 1
  sudo mv nasm*/nasm /usr/local/bin/ || exit 1
  sudo mv nasm*/ndisasm /usr/local/bin/ || exit 1
  rm -rf "${nasmzip}" nasm-*
  popd >/dev/null
fi

if [ "$(which mtoc.NEW)" == "" ] || [ "$(which mtoc)" == "" ]; then
  echo "Missing mtoc or mtoc.NEW!"
  echo "To build mtoc follow: https://github.com/tianocore/tianocore.github.io/wiki/Xcode#mac-os-x-xcode"
  prompt "Install prebuilt mtoc and mtoc.NEW automatically?"
  pushd /tmp >/dev/null
  rm -f mtoc mtoc-mac64.zip
  curl -OL "https://github.com/acidanthera/ocbuild/raw/master/external/mtoc-mac64.zip" || exit 1
  unzip -q mtoc-mac64.zip mtoc || exit 1
  sudo mkdir -p /usr/local/bin || exit 1
  sudo cp mtoc /usr/local/bin/mtoc || exit 1
  sudo mv mtoc /usr/local/bin/mtoc.NEW || exit 1
  popd >/dev/null
fi

if [ ! -d "Binaries" ]; then
  mkdir Binaries || exit 1
  cd Binaries || exit 1
  ln -s ../edk2/Build/OpenCorePkg/RELEASE_XCODE5/X64 RELEASE || exit 1
  ln -s ../edk2/Build/OpenCorePkg/DEBUG_XCODE5/X64 DEBUG || exit 1
  ln -s ../edk2/Build/OpenCorePkg/NOOPT_XCODE5/X64 NOOPT || exit 1
  cd .. || exit 1
fi

while true; do
  if [ "$1" == "--skip-tests" ]; then
    SKIP_TESTS=1
    shift
  elif [ "$1" == "--skip-build" ]; then
    SKIP_BUILD=1
    shift
  elif [ "$1" == "--skip-package" ]; then
    SKIP_PACKAGE=1
    shift
  else
    break
  fi
done

if [ "$1" != "" ]; then
  MODE="$1"
  shift
fi

if [ ! -f edk2/edk2.ready ]; then
  rm -rf edk2

  sym=$(find . -not -type d -exec file "{}" ";" | grep CRLF)
  if [ "${sym}" != "" ]; then
    echo "Repository CRLF line endings"
    exit 1
  fi
fi

updaterepo "https://github.com/tianocore/edk2.git" edk2 master || exit 1
cd edk2
updaterepo "https://github.com/acidanthera/EfiPkg" EfiPkg master || exit 1
updaterepo "https://github.com/acidanthera/MacInfoPkg" MacInfoPkg master || exit 1
updaterepo "https://github.com/n-d-k/OcSupportPkg.git" OcSupportPkg master || exit 1
updaterepo "https://github.com/n-d-k/NvmExpressDxePkg.git" NvmExpressDxePkg master || exit 1

if [ ! -d OpenCorePkg ]; then
  ln -s .. OpenCorePkg || exit 1
fi

source edksetup.sh || exit 1

if  [[ ! -x "$EDK_TOOLS_PATH/Source/C/bin/GenFv" ]]; then
        echo "Building tools as they are not found"
        make -C "$WORKSPACE"/BaseTools CC="gcc -Wno-deprecated-declarations"
        touch UDK.ready

fi
[ ! -d $HOME/src/opt/local/cross/bin ] && echo no GCC5 && exit 1
if  [[ ! -x "$HOME/src/opt/local/cross/bin/x86_64-clover-linux-gnu-make" ]]; then
	cp -r /usr/bin/make $HOME/src/opt/local/cross/bin/x86_64-clover-linux-gnu-make
fi

if [ "$SKIP_BUILD" != "1" ]; then
  if [ "$MODE" = "" ] || [ "$MODE" = "DEBUG" ]; then
    build -a X64 -b DEBUG -t $TOOLCHAIN -n $BUILDTHREADS -p OpenCorePkg/OpenCorePkg.dsc || exit 1
  fi

  if [ "$MODE" = "" ] || [ "$MODE" = "DEBUG" ]; then
    build -a X64 -b NOOPT -t $TOOLCHAIN -n $BUILDTHREADS -p OpenCorePkg/OpenCorePkg.dsc || exit 1
  fi

  if [ "$MODE" = "" ] || [ "$MODE" = "RELEASE" ]; then
    build -a X64 -b RELEASE -t $TOOLCHAIN -n $BUILDTHREADS -p OpenCorePkg/OpenCorePkg.dsc || exit 1
  fi
fi

cd .. || exit 1

if [ "$SKIP_PACKAGE" != "1" ]; then
  if [ "$PACKAGE" = "" ] || [ "$PACKAGE" = "DEBUG" ]; then
    package "Binaries/DEBUG" "DEBUG" || exit 1
  fi

  if [ "$PACKAGE" = "" ] || [ "$PACKAGE" = "RELEASE" ]; then
    package "Binaries/RELEASE" "RELEASE" || exit 1
  fi
fi

if [[ -d "$(pwd)"/edk2/Build/OpenCorePkg/RELEASE_XCODE5/X64 ]]; then
  open "$(pwd)"/edk2/Build/OpenCorePkg/RELEASE_XCODE5/X64
else
  echo && echo "Directory not found."
  sleep 2
fi
