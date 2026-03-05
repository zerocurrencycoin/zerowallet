#-------------------------------------------------
#
# Project created by QtCreator 2018-10-05T09:54:45
#
#-------------------------------------------------

QT       += core gui network

CONFIG += precompile_header

PRECOMPILED_HEADER = src/precompiled.h

QT += widgets
QT += websockets

TARGET = zerowallet

TEMPLATE = app

# Suppress Qt deprecation warnings project-wide.
QMAKE_CXXFLAGS += -Wno-deprecated-declarations

INCLUDEPATH  += src/3rdparty/
INCLUDEPATH  += src/

RESOURCES     = application.qrc

MOC_DIR = bin
OBJECTS_DIR = bin
UI_DIR = src
# Windows (MXE): all build artifacts in debug/ or release/
win32: CONFIG(debug, debug|release): MOC_DIR = debug
win32: CONFIG(debug, debug|release): OBJECTS_DIR = debug
win32: CONFIG(debug, debug|release): DESTDIR = debug
else: win32: CONFIG(release, debug|release): MOC_DIR = release
else: win32: CONFIG(release, debug|release): OBJECTS_DIR = release
else: win32: CONFIG(release, debug|release): DESTDIR = release

CONFIG += c++14

SOURCES += \
    src/main.cpp \
    src/mainwindow.cpp \
    src/rpc.cpp \
    src/balancestablemodel.cpp \
    src/3rdparty/qrcode/BitBuffer.cpp \
    src/3rdparty/qrcode/QrCode.cpp \
    src/3rdparty/qrcode/QrSegment.cpp \
    src/settings.cpp \
    src/sendtab.cpp \
    src/txtablemodel.cpp \
    src/globalzntablemodel.cpp \
    src/localzntablemodel.cpp \
    src/turnstile.cpp \
    src/qrcodelabel.cpp \
    src/connection.cpp \
    src/fillediconlabel.cpp \
    src/addressbook.cpp \
    src/logger.cpp \
    src/addresscombo.cpp \
    src/validateaddress.cpp \
    src/websockets.cpp \
    src/mobileappconnector.cpp \
    src/recurring.cpp \
    src/requestdialog.cpp \
    src/memoedit.cpp \
    src/viewalladdresses.cpp

HEADERS += \
    src/mainwindow.h \
    src/precompiled.h \
    src/rpc.h \
    src/balancestablemodel.h \
    src/3rdparty/qrcode/BitBuffer.hpp \
    src/3rdparty/qrcode/QrCode.hpp \
    src/3rdparty/qrcode/QrSegment.hpp \
    src/3rdparty/json/json.hpp \
    src/settings.h \
    src/txtablemodel.h \
    src/globalzntablemodel.h \
    src/localzntablemodel.h \
    src/turnstile.h \
    src/qrcodelabel.h \
    src/connection.h \
    src/fillediconlabel.h \
    src/addressbook.h \
    src/logger.h \
    src/addresscombo.h \
    src/validateaddress.h \
    src/websockets.h \
    src/mobileappconnector.h \
    src/recurring.h \
    src/requestdialog.h \
    src/memoedit.h \
    src/viewalladdresses.h

FORMS += \
    src/mainwindow.ui \
    src/migration.ui \
    src/recurringpayments.ui \
    src/settings.ui \
    src/about.ui \
    src/confirm.ui \
    src/turnstile.ui \
    src/turnstileprogress.ui \
    src/privkey.ui \
    src/memodialog.ui \
    src/validateaddress.ui \
    src/viewalladdresses.ui \
    src/connection.ui \
    src/zboard.ui \
    src/addressbook.ui \
    src/mobileappconnector.ui \
    src/createzcashconfdialog.ui \
    src/recurringdialog.ui \
    src/newrecurring.ui \
    src/requestdialog.ui \
    src/recurringmultiple.ui \
    src/znsetup.ui


TRANSLATIONS = res/zero_qt_wallet_es.ts \
               res/zero_qt_wallet_fr.ts \
               res/zero_qt_wallet_de.ts \
               res/zero_qt_wallet_pt.ts \
               res/zero_qt_wallet_it.ts \
               res/zero_qt_wallet_zh.ts \
               res/zero_qt_wallet_ru.ts \
               res/zero_qt_wallet_uk.ts \
               res/zero_qt_wallet_tr.ts

include(singleapplication/singleapplication.pri)
DEFINES += QAPPLICATION_CLASS=QApplication

QMAKE_INFO_PLIST = res/Info.plist

# macOS dev build: strip leftover Frameworks/PlugIns from prior mkrelease to avoid duplicate Qt load.
# Symlink PlugIns to Homebrew Qt plugins so app finds cocoa platform plugin (mkrelease overwrites).
macx {
    clean-app-deploy.target = clean-app-deploy
    clean-app-deploy.commands = -rm -rf zerowallet.app/Contents/Frameworks zerowallet.app/Contents/PlugIns
    clean-app-deploy.depends = FORCE
    QMAKE_EXTRA_TARGETS += clean-app-deploy
    PRE_TARGETDEPS += clean-app-deploy

    QT5_PREFIX = $$system(brew --prefix qt@5)
    QMAKE_POST_LINK = ln -sf $$QT5_PREFIX/plugins zerowallet.app/Contents/PlugIns
}

win32: RC_ICONS = res/icon.ico
ICON = res/logo.icns

libsodium.target = $$PWD/res/libsodium.a
win32: libsodium.commands = res/libsodium/buildlibsodium-win.sh
else: libsodium.commands = res/libsodium/buildlibsodium.sh

QMAKE_EXTRA_TARGETS += libsodium
QMAKE_CLEAN += res/libsodium.a

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

win32:CONFIG(release, debug|release): LIBS += -L$$PWD/res/ -llibsodium
else:win32:CONFIG(debug, debug|release): LIBS += -L$$PWD/res/ -llibsodiumd
else:unix: LIBS += -L$$PWD/res/ -lsodium

INCLUDEPATH += $$PWD/res
DEPENDPATH += $$PWD/res

win32-g++:CONFIG(release, debug|release): PRE_TARGETDEPS += $$PWD/res/liblibsodium.a
else:win32-g++:CONFIG(debug, debug|release): PRE_TARGETDEPS += $$PWD/res/liblibsodium.a
else:win32:!win32-g++:CONFIG(release, debug|release): PRE_TARGETDEPS += $$PWD/res/libsodium.lib
else:win32:!win32-g++:CONFIG(debug, debug|release): PRE_TARGETDEPS += $$PWD/res/libsodiumd.lib
else:unix: PRE_TARGETDEPS += $$PWD/res/libsodium.a

DISTFILES +=
