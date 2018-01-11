export CODESIGN_ALLOCATE=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate
    
#Signing Identity:     "Mac Developer: Kong XiangBo (RWX8LR4XNX)"

cd ../Carthage/Build/Mac/ 
#    /usr/bin/codesign --force --sign 16B002250F14633E0CC0B2915EB8587D50772A42 --preserve-metadata=identifier,entitlements,flags --timestamp=none /Users/yarshure/Library/Developer/Xcode/DerivedData/SFSocket-bhlabqkgxpoujuctgwhoiafccven/Build/Products/Debug/VPNTest.app/Contents/Frameworks/lwip.framework/Versions/A

find . -name '*.framework' -type d | while read -r FRAMEWORK
do
echo "codesign $FRAMEWORK"
/usr/bin/codesign --sign  16B002250F14633E0CC0B2915EB8587D50772A42 --force --preserve-metadata=identifier,entitlements,flags --timestamp=none "$FRAMEWORK/Versions/A"
done

cd -
