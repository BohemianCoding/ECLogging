#!/usr/bin/env bash

# Common code for scripts that use xcode

build()
{
echo "Building $1 for $3 $5"
workspace="$1"
scheme="$2"
sdk="$3"
actions="$4"
config="$5"
arch="$6"
dest="$7"
log="$8"

echo "Workspace:$workspace"
echo "Scheme:$scheme"
echo "SDK:$sdk"
echo "Actions:$actions"
echo "Config:$config"
echo "Arch:$arch"
echo "Build to:$dest"
echo "Log to:$dest"

outlog="${log}/out.log"
errlog="${log}/error.log"

xcodebuild -workspace "$workspace" -scheme "$scheme" -sdk "$sdk" $actions -config "$config" -arch "$arch" OBJROOT="$dest/obj/" SYMROOT="$dest/sym" >> "$outlog" 2>> "$errlog"

result=$?
if [[ $result != 0 ]]; then
cat "$errlog"
echo
echo "** BUILD FAILURES **"
echo "Build failed for scheme $scheme"
exit $result
fi

failures=`grep failed "$outlog"`
if [[ $failures != "" ]]; then
echo $failures
echo
echo "** UNIT TEST FAILURES **"
echo "Tests failed for scheme $scheme"
exit $result
fi

}