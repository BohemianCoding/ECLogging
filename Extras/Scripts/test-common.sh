#!/usr/bin/env bash

# Common code for test scripts

if [[ `which xctool` == "" ]]
then
  use_xctool=false
else
  use_xctool=true
fi

if [[ $project == "" ]];
then
    echo "Need to define project variable."
    exit 1
fi

if [[ $ecbase == "" ]];
then
echo "Need to set ecbase variable - assuming it's at $base/.. (which is probably wrong)."
ecbase="$base/.."
fi

echo "Preparing to build $project"

buildname="build"
build="$PWD/$buildname"
oldbuild="$build.old"

pushd "$ecbase" > /dev/null
wd=`pwd`
ocunit2junit="$wd/ocunit2junit/bin/ocunit2junit"
popd > /dev/null

derived="derived"
sym="$build/built"
obj="$build/$derived/objects"
dst="$build/$derived/dst"
precomp="$build/$derived/precompiled-headers"
modulespath=$"$derived/modules"
modules="$build/$modulespath"

rm -rfd "$oldbuild" 2> /dev/null
mv "$build" "$oldbuild"
mkdir -p "$build/$modulespath"
mv "$oldbuild/$modulespath" "$build/$derived/" 2> /dev/null
rm -rfd "$oldbuild" 2> /dev/null

config="Debug"

urlencode()
{
    encoded="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1")"
}

report()
{
    pushd "$build" > /dev/null 2>> "$testerr"
    "$ocunit2junit" < "$testout" > /dev/null 2>> "$testerr"
    reportdir="$build/reports/$1 ($2)"
    mkdir -p "$reportdir"
    mv test-reports/* "$reportdir" 2>> "$testerr"
    rmdir test-reports 2>> "$testerr"
    popd > /dev/null 2>> "$testerr"
}

cleanbuild()
{
    # ensure a clean build every time
    rm -rfd "$obj" 2> /dev/null
    rm -rfd "$dst" 2> /dev/null
    rm -rfd "$sym" 2> /dev/null
    rm -rfd "$precomp" > /dev/null
}

cleanoutput()
{
    logdir="$build/logs"
    mkdir -p "$logdir"
    logfile="$logdir/$1-$2"
    testout="$logfile.log"
    testerr="$logfile-errors.log"

    # make empty output files
    echo "" > "$testout"
    echo "" > "$testerr"
}

setup()
{
    local TOOL="$1"
    shift

    local SCHEME="$1"
    shift

    local PLATFORM="$1"
    shift

    echo "Building $SCHEME for $PLATFORM with $TOOL"
    echo "Actions: $@"
    cleanoutput "$SCHEME" "$PLATFORM"
}

commonbuildxctool()
{
    local PLATFORM="$1"
    shift

    local SCHEME="$1"
    shift

    setup "xctool" "$SCHEME" "$PLATFORM" "$@"

    reportdir="$build/reports"
    mkdir -p "$reportdir"

    xctool -workspace "$project.xcworkspace" -scheme "$SCHEME" -sdk "$PLATFORM" "$@" OBJROOT="$obj" SYMROOT="$sym" DSTROOT="$dst" SHARED_PRECOMPS_DIR="$precomp" MODULE_CACHE_DIR="$modules" -reporter "junit:$reportdir/$SCHEME-$PLATFORM-report.xml" -reporter "pretty:$testout" 2>> "$testerr"
    result=$?

    if [[ $result != 0 ]]
    then
        echo "Build Failed"
        #cat "$testout"
        cat "$testerr" >&2
        tail "$testout"
        echo
        echo "** BUILD FAILURES **"
        echo "xxctool returned $result"

        echo "Build failed for scheme $1"
        urlencode "${JOB_URL}/$buildname/logs/$1-$3"
        echo "Full log: $encoded"

        exit $result
    fi
}

commonbuildxcbuild()
{
    local PLATFORM="$1"
    shift

    local SCHEME="$1"
    shift

    setup "xcworkspace" "$SCHEME" "$PLATFORM" "$@"


    # build it
    xcodebuild -workspace "$project.xcworkspace" -scheme "$SCHEME" -sdk "$PLATFORM" "$@" OBJROOT="$obj" SYMROOT="$sym" DSTROOT="$dst" SHARED_PRECOMPS_DIR="$precomp" MODULE_CACHE_DIR="$modules" >> "$testout" 2>> "$testerr"

    result=$?

    report "$SCHEME" "$PLATFORM"

    # we don't entirely trust the return code from xcodebuild, so we also scan the output for "failed"
    buildfailures=`grep failed "$testerr"`
    if ([[ $result != 0 ]] && [[ $result != 65 ]]) || [[ $buildfailures != "" ]]; then
        # if it looks like the build failed, output everything to stdout
        echo "Build Failed"
        #cat "$testout"
        cat "$testerr" >&2
        echo
        echo "** BUILD FAILURES **"
        if [[ $result != 0 ]]; then
          echo "xcodebuild returned $result"
        fi

        if [[ $buildfailures != "" ]]; then
          echo "Found failure in log: $buildfailures"
        fi
        echo "Build failed for scheme $SCHEME"
        urlencode "${JOB_URL}/$buildname/logs/$SCHEME-$PLATFORM"
        echo "Full log: $encoded"
        if [[ $result == 0 ]]; then
            result=1
        fi
        exit $result
    fi


    testfailures=`grep failed "$testout"`
    if [[ $testfailures != "" ]] && [[ $testfailures != "error: failed to launch"* ]]; then
        echo "** UNIT TEST FAILURES **"
        echo "Found failure in log:$testfailures"
        echo
        echo "Tests failed for scheme $SCHEME"
        exit 1
    fi

}

commonbuild()
{
  if $use_xctool
  then
    commonbuildxctool "$@"
  else
    commonbuildxcbuild "$@"
  fi
}

macbuild()
{
    if $testMac ; then
        if [[ $1 != "--dontclean" ]]
        then
            cleanbuild
        else
            echo "Suppressing cleaning - will reuse the same build products"
            shift
        fi

        commonbuild "macosx" "$@"
    fi
}

iosbuild()
{
    if $testIOS; then

        local SCHEME=$1
        shift

        local ACTIONS=$1
        shift
        if ! $use_xctool
        then
          if [[ $ACTIONS == "test" ]];
          then
              ACTIONS="build TEST_AFTER_BUILD=YES"
          fi
        fi
        cleanbuild
        commonbuild "iphonesimulator" "$SCHEME" "$ACTIONS" -arch i386 ONLY_ACTIVE_ARCH=NO "$@"
    fi
}

iosbuildproject()
{

    if $testIOS; then

        cleanbuild
        cleanoutput "$1" "$2"

        cd "$1"
        echo Building debug target $2 of project $1
        xcodebuild -project "$1.xcodeproj" -config "Debug" -target "$2" -arch i386 -sdk "iphonesimulator" build OBJROOT="$obj" SYMROOT="$sym" DSTROOT="$dst" SHARED_PRECOMPS_DIR="$precomp" MODULE_CACHE_DIR="$modules" >> "$testout" 2>> "$testerr"
        echo Building release target $2 of project $1
        xcodebuild -project "$1.xcodeproj" -config "Release" -target "$2" -arch i386 -sdk "iphonesimulator" build OBJROOT="$obj" SYMROOT="$sym" DSTROOT="$dst" SHARED_PRECOMPS_DIR="$precomp" MODULE_CACHE_DIR="$modules" >> "$testout" 2>> "$testerr"
        result=$?
        cd ..
        if [[ $result != 0 ]]; then
            cat "$testerr"
            echo
            echo "** BUILD FAILURES **"
            echo "Build failed for scheme $1"
        exit $result
        fi

    fi

}

iostestproject()
{

    if $testIOS; then

        cleanoutput "$1" "$2"
        cleanbuild

        cd "$1"
        echo Testing debug target $2 of project $1
        xcodebuild -project "$1.xcodeproj" -config "Debug" -target "$2" -arch i386 -sdk "iphonesimulator" build OBJROOT="$obj" SYMROOT="$sym" DSTROOT="$dst" SHARED_PRECOMPS_DIR="$precomp" MODULE_CACHE_DIR="$modules" TEST_AFTER_BUILD=YES >> "$testout" 2>> "$testerr"
        echo Testing release target $2 of project $1
        xcodebuild -project "$1.xcodeproj" -config "Release" -target "$2" -arch i386 -sdk "iphonesimulator" build OBJROOT="$obj" SYMROOT="$sym" DSTROOT="$dst" SHARED_PRECOMPS_DIR="$precomp" MODULE_CACHE_DIR="$modules" TEST_AFTER_BUILD=YES >> "$testout" 2>> "$testerr"
        result=$?
        cd ..
        if [[ $result != 0 ]]; then
            cat "$testerr"
            echo
            echo "** BUILD FAILURES **"
            echo "Build failed for scheme $1"
            exit $result
        fi

        report "$1" "iphonesimulator"

    fi

}