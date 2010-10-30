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
chromiumappdir="build/chromium/src/xcodebuild/Release/Chromium.app"
if [ \! -d "$chromiumappdir" ]; then
    echo "You need to build chromium first!"
    echo "If done, $chromiumappdir should exist."
    exit 1
fi
rm CMakeCache.txt
cmake . -DCMAKE_BUILD_TYPE=Release || exit 1
make || exit 1

echo "Installing into $outdir"
mkdir "$outdir" || echo "Note: installing into unclean directory! You may end up with unused files."
mkdir -p "$outdir/bin"
mkdir -p "$outdir/include/berkelium"
mkdir -p "$outdir/lib"
mkdir -p "$outdir/Versions"
for versionsrc in "build/chromium/src/xcodebuild/Release/Chromium.app/Contents/Versions"/*; do
    versionnum=$(basename "$versionsrc")
done
versiondst="$outdir/Versions/$versionnum"
mkdir -p "$versiondst"
ln -fs '../../lib/Chromium Framework.framework' "$versiondst/Chromium Framework.framework"
mkdir -p "$outdir/lib/Chromium Framework.framework/Libraries"
cp "$versionsrc/Chromium Framework.framework/Libraries/libffmpegsumo.dylib" "$outdir/lib/Chromium Framework.framework/Libraries/"
mkdir -p "$outdir/lib/Chromium Framework.framework/Resources/en.lproj"
for copyfile in chrome.pak common.sb nacl_loader.sb renderer.sb utility.sb worker.sb en.lproj/locale.pak; do
    cp "$versionsrc/Chromium Framework.framework/Resources/$copyfile" "$outdir/lib/Chromium Framework.framework/Resources/$copyfile"
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

echo "Installing GLUT Sample.app"
mkdir -p "$outdir/GLUT Sample.app/Contents/MacOS"
ln -fs '../../lib' "$outdir/GLUT Sample.app/Contents/lib"
ln -fs '../../Versions' "$outdir/GLUT Sample.app/Contents/Versions"
for exe in berkelium glut_input libplugin_carbon_interpose.dylib; do
    cp "$outdir/bin/$exe" "$outdir/GLUT Sample.app/Contents/MacOS/$exe"
done
cat > "$outdir/GLUT Sample.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>Sample Berkelium GLUT Application</string>
	<key>CFBundleExecutable</key>
	<string>glut_input</string>
	<key>CFBundleIdentifier</key>
	<string>org.chromium.Chromium.helper</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>GLUT Sample</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$versionnum</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>$versionnum</string>
	<key>LSFileQuarantineEnabled</key>
	<true/>
	<key>LSHasLocalizedDisplayName</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.5.0</string>
	<key>LSUIElement</key>
	<string>1</string>
</dict>
</plist>
EOF


chmod -R a+rX "$outdir"
archivename="${outdir}-$(date +%Y-%m-%d).tgz"
echo "Tarring into $archivename ..."
tar -zcf "$archivename" "$outdir" >/dev/null
echo "Done!"
