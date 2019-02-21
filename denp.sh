#!/bin/sh

# Config

export GRDB_DIR="/tmp/GRDB_project_name_temp"
export GRDB_REF="Swift-5.0"   # commit/branch/etc. you want to use

export SQLITELIB_XCCONFIG='
CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_JSON1
'
export GRDBCUSTOM_XCCONFIG='
CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK -D SQLITE_ENABLE_JSON1
'
export GRDBCUSTOM_H='
#define SQLITE_ENABLE_FTS5
#define SQLITE_ENABLE_PREUPDATE_HOOK
#define SQLITE_ENABLE_JSON1
'

# Build setup

rm -rf "$GRDB_DIR"

git clone git@github.com:groue/GRDB.swift "$GRDB_DIR"
cd "$GRDB_DIR"
git checkout "$GRDB_REF"

git submodule update --init SQLiteCustom/src
git rm --cached -r SQLiteCustom/src
git config -f .gitmodules --remove-section submodule.SQLiteCustom/src
rm -rf SQLiteCustom/src/.git
git add SQLiteCustom/src

echo "$SQLITELIB_XCCONFIG" >> SQLiteCustom/src/SQLiteLib-USER.xcconfig
echo "$GRDBCUSTOM_XCCONFIG" >> SQLiteCustom/GRDBCustomSQLite-USER.xcconfig
echo "$GRDBCUSTOM_H" >> SQLiteCustom/GRDBCustomSQLite-USER.h

# these files are .gitignore'd but we need them checked in because Carthage is gonna clone this repo...
git add -f SQLiteCustom/GRDBCustomSQLite-USER.xcconfig SQLiteCustom/GRDBCustomSQLite-USER.h SQLiteCustom/src/SQLiteLib-USER.xcconfig

git commit -am "Patching GRDB source code for Carthage compatibility"
git checkout -b patched-for-carthage
