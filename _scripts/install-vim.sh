#!/bin/bash

set -ev

case "${TRAVIS_OS_NAME}" in
	linux)
		git clone --depth 1 --branch "${VIM_VERSION}" https://github.com/vim/vim /tmp/vim
		cd /tmp/vim
		./configure --prefix="${HOME}/vim" --with-features=huge \
			--enable-luainterp --enable-fail-if-missing
		make -j2
		make install
		;;
	osx)
		export HOMEBREW_NO_AUTO_UPDATE=1
		brew update
		brew install macvim --with-override-system-vim --with-lua
		;;
	*)
		echo "Unknown value of \${TRAVIS_OS_NAME}: ${TRAVIS_OS_NAME}"
		exit 65
		;;
esac
