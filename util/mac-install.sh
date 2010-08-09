#!/bin/bash

outdir="$1"
if [ x = x"$outdir" ]; then
    echo "Usage: $0 output-directory"
    echo
    echo "Copies just the necessary files for mac into a single directory."
    echo "Will also compress these files into a tarball with today's date."
    echo
    echo "Warnings:"
    echo "- Run from the berkelium dir. Assumes Release chromium build in ./build/chromium."
    echo "- Do not run as root."
    echo "- Requires that the directory you compiled in is at least 23 characters long:"
    echo "  (e.g. /Users/alfred/berkelium but not /Users/al/berkelium)"
    echo "  This is because we replace strings in the executable files."
    exit 1
fi

echo "Installing into $outdir"
chromiumappdir="build/chromium/xcodebuild/Release/Chromium.app"
mkdir "$outdir" || echo "Note: installing into unclean directory! You may end up with unused files."
mkdir -p "$outdir/bin"
mkdir -p "$outdir/include/berkelium"
mkdir -p "$outdir/lib"
mkdir -p "$outdir/MacOS"
mkdir -p "$outdir/Versions"
ln -fs '../bin/berkelium' "$outdir/MacOS/berkelium"
for versionsrc in "build/chromium/src/xcodebuild/Release/Chromium.app/Contents/Versions"/*; do
    versiondst="$outdir/Versions/"$(basename "$versionsrc")
    mkdir -p "$versiondst"
    ln -fs '../../lib/Chromium Framework.framework' "$versiondst/Chromium Framework.framework"
    mkdir -p "$outdir/lib/Chromium Framework.framework/Libraries"
    mkdir -p "$outdir/lib/Chromium Framework.framework/Resources/en.lproj"
    for copyfile in chrome.pak common.sb nacl_loader.sb renderer.sb utility.sb worker.sb en.lproj/locale.pak; do
        cp "$versionsrc/Chromium Framework.framework/Resources/$copyfile" "$outdir/lib/Chromium Framework.framework/Resources/$copyfile"
    done
done
for header in "include/berkelium"/*; do
    cp "$header" "$outdir/$header"
done
g++ util/bin_replace.cpp -o ./bin_replace
for exe in berkelium ppmrender glut_demo glut_input libplugin_carbon_interpose.dylib; do
    echo "Installing executable $exe"
    ./bin_replace "$PWD/" '@executable_path/../lib/' < "$exe" > "$outdir/bin/$exe"
    chmod +x "$outdir/bin/$exe"
done
lib="liblibberkelium.dylib"
echo "Installing shared library $lib ..."
./bin_replace "$PWD/$lib" '@executable_path/../lib/'"$lib" < "$lib" | \
    ./bin_replace "$PWD/" 'Berkelium/' > "$outdir/lib/$lib"
chmod +x "$outdir/lib/$lib"

chmod -R a+rX "$outdir"
archivename="${outdir}-$(date +%Y-%m-%d).tgz"
echo "Tarring into $archivename ..."
tar -zcf "$archivename" "$outdir" >/dev/null
echo "Done!"
