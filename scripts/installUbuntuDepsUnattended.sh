#!/usr/bin/env bash
SCRIPT=`pwd`/$0
FILENAME=`basename $SCRIPT`
PATHNAME=`dirname $SCRIPT`
ROOT=$PATHNAME/..
BUILD_DIR=$ROOT/build
CURRENT_DIR=`pwd`

LIB_DIR=$BUILD_DIR/libdeps
PREFIX_DIR=$LIB_DIR/build/

pause() {
  read -p "$*"
}

parse_arguments(){
  while [ "$1" != "" ]; do
    case $1 in
      "--enable-gpl")
        ENABLE_GPL=true
        ;;
      "--cleanup")
        CLEANUP=true
        ;;
    esac
    shift
  done
}

check_proxy(){
  if [ -z "$http_proxy" ]; then
    echo "No http proxy set, doing nothing"
  else
    echo "http proxy configured, configuring npm"
    npm config set proxy $http_proxy
  fi

  if [ -z "$https_proxy" ]; then
    echo "No https proxy set, doing nothing"
  else
    echo "https proxy configured, configuring npm"
    npm config set https-proxy $https_proxy
  fi
}

install_apt_deps(){
  sudo apt-get update -y
  sudo apt-get install -qq python-software-properties -y
  sudo apt-get install -qq software-properties-common -y
  sudo add-apt-repository ppa:chris-lea/node.js -y
  sudo apt-get update -y
  sudo apt-get install -qq git make gcc g++ libssl-dev cmake libglib2.0-dev pkg-config nodejs libboost-regex-dev libboost-thread-dev libboost-system-dev liblog4cxx10-dev rabbitmq-server mongodb openjdk-6-jre curl libboost-test-dev -y
  sudo npm install -g node-gyp
  sudo chown -R `whoami` ~/.npm ~/tmp/
}

install_openssl(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./openssl-1.0.1g.tar.gz ]; then
      curl -O https://www.openssl.org/source/old/1.0.1/openssl-1.0.1g.tar.gz
      tar -zxvf openssl-1.0.1g.tar.gz
      cd openssl-1.0.1g
      ./config --prefix=$PREFIX_DIR -fPIC
      make -s V=0
      make install_sw
    else
      echo "openssl already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_openssl
  fi
}

install_libnice(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./libnice-0.1.4.tar.gz ]; then
      curl -O https://nice.freedesktop.org/releases/libnice-0.1.4.tar.gz
      tar -zxvf libnice-0.1.4.tar.gz
      cd libnice-0.1.4
      patch -R ./agent/conncheck.c < $PATHNAME/libnice-014.patch0
      ./configure --prefix=$PREFIX_DIR
      make -s V=0
      make install
    else
      echo "libnice already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_libnice
  fi
}

install_opus(){
  [ -d $LIB_DIR ] || mkdir -p $LIB_DIR
  cd $LIB_DIR
  if [ ! -f ./opus-1.1.tar.gz ]; then
    curl -O http://downloads.xiph.org/releases/opus/opus-1.1.tar.gz
    tar -zxvf opus-1.1.tar.gz
    cd opus-1.1
    ./configure --prefix=$PREFIX_DIR
    make -s V=0
    make install
  else
    echo "opus already installed"
  fi
  cd $CURRENT_DIR
}

install_mediadeps(){
  install_opus
  sudo apt-get -qq install yasm libvpx. libx264.
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./libav-11.1.tar.gz ]; then
      curl -O https://www.libav.org/releases/libav-11.1.tar.gz
      tar -zxvf libav-11.1.tar.gz
      cd libav-11.1
      PKG_CONFIG_PATH=${PREFIX_DIR}/lib/pkgconfig ./configure --prefix=$PREFIX_DIR --enable-shared --enable-gpl --enable-libvpx --enable-libx264 --enable-libopus
      make -s V=0
      make install
    else
      echo "libav already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_mediadeps
  fi

}

install_mediadeps_nogpl(){
  install_opus
  sudo apt-get -qq install yasm libvpx.
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./libav-11.1.tar.gz ]; then
      curl -O https://www.libav.org/releases/libav-11.1.tar.gz
      tar -zxvf libav-11.1.tar.gz
      cd libav-11.1
      PKG_CONFIG_PATH=${PREFIX_DIR}/lib/pkgconfig ./configure --prefix=$PREFIX_DIR --enable-shared --enable-gpl --enable-libvpx --enable-libopus
      make -s V=0
      make install
    else
      echo "libav already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_mediadeps_nogpl
  fi
}

install_libsrtp(){
  if [ ! -f $PREFIX_DIR/lib/libsrtp.a ]; then
    cd $ROOT/third_party/srtp
    CFLAGS="-fPIC" ./configure --prefix=$PREFIX_DIR
    make -s V=0
    make uninstall
    make install
    cd $CURRENT_DIR
  else
    echo "srtp already installed"
  fi
}

cleanup(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    rm -r libnice*
    rm -r libav*
    rm -r openssl*
    rm -r opus*
    cd $CURRENT_DIR
  fi
}

parse_arguments $*

mkdir -p $PREFIX_DIR

install_apt_deps
check_proxy
install_openssl
install_libnice
install_libsrtp

install_opus
if [ "$ENABLE_GPL" = "true" ]; then
  install_mediadeps
else
  install_mediadeps_nogpl
fi

if [ "$CLEANUP" = "true" ]; then
  echo "Cleaning up..."
  cleanup
fi
