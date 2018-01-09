#  issue
### copy framework

```

export CODESIGN_ALLOCATE=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate
fpath="${SRCROOT}/Carthage/Build/Mac"
cd "$fpath"

tar -c *.framework |tar -xvC "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

find . -name '*.framework' -type d | while read -r FRAMEWORK
do
echo "codesign $FRAMEWORK"
//when debug every time run will execute codesign ,it's too slow
///usr/bin/codesign --sign  $EXPANDED_CODE_SIGN_IDENTITY --force --preserve-metadata=identifier,entitlements,flags --timestamp=none "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/$FRAMEWORK/Versions/A"
done
```

