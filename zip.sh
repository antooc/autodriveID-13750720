#!/bin/bash

set -e

version=$1
factorio=$2
modname=$(grep '"name":' templates/info.json | awk -F '"' '{print $4}')

[ -z "$version" ] && (echo "expected version" 1>&2; exit 1)
[ -z "$factorio" ] && (echo "expected factorio path" 1>&2; exit 1)

sed -r "s/VERSION/${version}/" templates/info.json > info.json

rm -f migrations/*.lua
cp templates/update-techs-recipes.lua migrations/${version}-techs-recipes.lua

mod="${modname}_${version}"

rm -rf $factorio/mods/$modname*
cp -r $(pwd) $factorio/mods/$mod
rm -rf $factorio/mods/$mod/.git
rm -rf $factorio/mods/$mod/render
rm -rf $factorio/mods/$mod/*sh
rm -rf $factorio/mods/$mod/.gitignore
rm -rf $factorio/mods/$mod/Makefile
rm -rf $factorio/mods/$mod/templates

pushd $factorio/mods
zip -r $mod.zip $mod
rm -rf $mod
popd
