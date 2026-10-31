#include "connection.h"
#include "mainwindow.h"
#include "settings.h"
#include "ui_connection.h"
#include "ui_createzcashconfdialog.h"
#include "rpc.h"

#include "precompiled.h"

#include <QCryptographicHash>
#include <QStorageInfo>

using json = nlohmann::json;

ConnectionLoader::ConnectionLoader(MainWindow* main, RPC* rpc) {
    this->main = main;
    this->rpc  = rpc;

    d = new QDialog(main);
    connD = new Ui_ConnectionDialog();
    connD->setupUi(d);
    QPixmap logo(":/img/res/logobig.gif");
    connD->topIcon->setPixmap(logo.scaled(128, 128, Qt::KeepAspectRatio, Qt::SmoothTransformation));
}

ConnectionLoader::~ConnectionLoader() {
    delete d;
    delete connD;
}

void ConnectionLoader::loadConnection() {
    QTimer::singleShot(1, [=]() { this->doAutoConnect(); });
    if (!Settings::getInstance()->isHeadless())
        d->exec();
}

void ConnectionLoader::doAutoConnect(bool tryEzcashdStart) {
    // Priority 1: Ensure all params are present.
    if (!verifyParams()) {
        downloadParams([=]() { this->doAutoConnect(); });
        return;
    }

    // Priority 2: Try to connect to detect zero.conf and connect to it.
    auto config = autoDetectZcashConf();
    main->logger->write(QObject::tr("Attempting autoconnect"));

    if (config.get() != nullptr) {
        auto connection = makeConnection(config);

        refreshZcashdState(connection, [=] () {
            // Refused connection. So try and start embedded zerod
            if (Settings::getInstance()->useEmbedded()) {
                if (tryEzcashdStart) {
                    this->showInformation(QObject::tr("Starting embedded zerod"));
                    if (this->startEmbeddedZcashd()) {
                        // Embedded zerod started up. Wait a second and then refresh the connection
                        main->logger->write("Embedded zerod started up, trying autoconnect in 1 sec");
                        QTimer::singleShot(1000, [=]() { doAutoConnect(); } );
                    } else {
                        if (config->zcashDaemon) {
                            // zerod is configured to run as a daemon, so we must wait for a few seconds
                            // to let it start up.
                            main->logger->write("zerod is daemon=1. Waiting for it to start up");
                            this->showInformation(QObject::tr("zerod is set to run as daemon"), QObject::tr("Waiting for zerod"));
                            QTimer::singleShot(5000, [=]() { doAutoConnect(/* don't attempt to start ezcashd */ false); });
                        } else {
                            // Something is wrong.
                            // We're going to attempt to connect to the one in the background one last time
                            // and see if that works, else throw an error
                            main->logger->write("Unknown problem while trying to start zerod");
                            QTimer::singleShot(2000, [=]() { doAutoConnect(/* don't attempt to start ezcashd */ false); });
                        }
                    }
                } else {
                    // We tried to start ezcashd previously, and it didn't work. So, show the error.
                    main->logger->write("Couldn't start embedded zerod for unknown reason");
                    QString explanation;
                    if (config->zcashDaemon) {
                        explanation = QString() % QObject::tr("You have zerod set to start as a daemon, which can cause problems "
                            "with ZeroWallet\n\n."
                            "Please remove the following line from your zero.conf and restart ZeroWallet\n"
                            "daemon=1");
                    } else {
                        explanation = QString() % QObject::tr("Couldn't start the embedded zerod.\n\n"
                            "Please try restarting.\n\nIf you previously started zerod with custom arguments, you might need to reset zero.conf.\n\n"
                            "If all else fails, please run zerod manually.") %
                            (ezcashd ? QObject::tr("The process returned") + ":\n\n" % ezcashd->errorString() : QString(""));
                    }

                    this->showError(explanation);
                }
            } else {
                // zero.conf exists, there's no connection, and the user asked us not to start zerod. Error!
                main->logger->write("Not using embedded and couldn't connect to zerod");
                QString explanation = QString() % QObject::tr("Couldn't connect to zerod configured in zero.conf.\n\n"
                                      "Not starting embedded zerod because --no-embedded was passed");
                this->showError(explanation);
            }
        });
    } else {
        if (Settings::getInstance()->useEmbedded()) {
            // zero.conf was not found, so create one
            createZcashConf();
        } else {
            // Fall back to manual connect
            doManualConnect();
        }
    }
}

QString randomPassword() {
    static const char charset[] =
        "0123456789"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "abcdefghijklmnopqrstuvwxyz"
        "!@#$%^&*()_+-=[]{}|\\:;\"'<>?,./~";
    const int charsetLen = sizeof(charset) - 1;  // exclude null
    const int passwordLength = 20;

    std::string s;
    s.reserve(passwordLength);
    for (int i = 0; i < passwordLength; ++i)
        s += charset[randombytes_uniform(charsetLen)];
    return QString::fromStdString(s);
}

/**
 * This will create a new zero.conf, download Zero parameters.
 */
void ConnectionLoader::createZcashConf() {
    main->logger->write("createZcashConf");

    auto confLocation = zcashConfWritableLocation();
    QFileInfo fi(confLocation);

    QDialog d(main);
    Ui_createZcashConf ui;
    ui.setupUi(&d);

    QPixmap logo(":/img/res/zero.png");
    ui.chkFastSync->setEnabled(false); //Disable until option is available in zero
    ui.chkFastSync->setChecked(false);

    ui.lblTopIcon->setPixmap(logo.scaled(128, 128, Qt::KeepAspectRatio, Qt::SmoothTransformation));
    ui.btnPickDir->setEnabled(false);

    ui.grpAdvanced->setVisible(false);
    QObject::connect(ui.btnAdvancedConfig, &QPushButton::toggled, [=](bool isVisible) {
        ui.grpAdvanced->setVisible(isVisible);
        ui.btnAdvancedConfig->setText(isVisible ? QObject::tr("Hide Advanced Config") : QObject::tr("Show Advanced Config"));
    });

    QObject::connect(ui.chkCustomDatadir, &QCheckBox::stateChanged, [=](int chked) {
        if (chked == Qt::Checked) {
            ui.btnPickDir->setEnabled(true);
        }
        else {
            ui.btnPickDir->setEnabled(false);
        }
    });

    QObject::connect(ui.btnPickDir, &QPushButton::clicked, [=]() {
        QString startDir = ui.lblDirName->text();
        if (startDir.isEmpty())
            startDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
        auto datadir = QFileDialog::getExistingDirectory(main, QObject::tr("Choose data directory"), startDir, QFileDialog::ShowDirsOnly);
        if (!datadir.isEmpty()) {
            ui.lblDirName->setText(QDir::toNativeSeparators(datadir));
        }
    });

    // Show the dialog
    QString datadir = "";
    bool useTor = false;
    if (d.exec() == QDialog::Accepted) {
        datadir = ui.lblDirName->text();
        useTor = ui.chkUseTor->isChecked();
        if (!ui.chkAllowInternet->isChecked()) {
            Settings::getInstance()->setAllowFetchPrices(false);
            Settings::getInstance()->setCheckForUpdates(false);
        }
    }

    main->logger->write("Creating file " + confLocation);
    QDir().mkdir(fi.dir().absolutePath());

    QFile file(confLocation);
    if (!file.open(QIODevice::ReadWrite | QIODevice::Truncate)) {
        main->logger->write("Could not create zero.conf, returning");
        return;
    }

    QTextStream out(&file);

    out << "# Autogenerated by ZeroWallet\n";
    out << "server=1\n";
    out << "rpcuser=zero\n";
    out << "rpcpassword=" % randomPassword() << "\n";
    out << "rpcport=23811\n";
    out << "rpcworkqueue=256\n";
    out << "txindex=1\n";

    //DeleteTx
    out << "deletetx=1\n";
    out << "keeptxfornblocks=1\n";
    out << "keeptxnum=1\n";

    //consolidation
    out << "consolidation=1\n";
    out << "consolidationtxfee=10000\n";

    // Fast sync override
    // if (ui.chkFastSync->isChecked()) {
    //     out << "fastsync=1\n";
    // }


    // Datadir override
    if (!datadir.isEmpty()) {
        out << "datadir=" % datadir % "\n";
    }

    // Tor override
    if (useTor) {
        out << "proxy=127.0.0.1:9050\n";
    }

    file.close();

    // Now that zero.conf exists, try to autoconnect again
    this->doAutoConnect();
}


namespace {

// The proving parameters zerod loads at startup (init.cpp), with the source, sizes, and
// SHA-256 digests of the Zero node's zcutil/fetch-params.sh. The server holds each file as
// NAME.part.1 and NAME.part.2 (part 2 of the two Sapling files is empty); both parts are
// written in order to NAME.dl and hashed as they arrive, and NAME.dl replaces NAME only when
// its size and SHA-256 match.
struct ParamFile { const char* name; const char* sha256; qint64 size; };
const ParamFile kParamFiles[] = {
    {"sapling-spend.params",  "8e48ffd23abb3a5fd9c5589204f32d9c31285a04b78096ba40a79b75677efc13", 47958396},
    {"sapling-output.params", "2f0ebbcbb9bb0bcffe95a397e7eba89c29eb4dde6191c339db88570e3f3fb0e4", 3592860},
    {"sprout-groth16.params", "b685d700c60328498fbde589c8c7c484c722b788b265b72af448a5bf0ee55b50", 725523612},
};
const char* const kParamsUrl = "https://download.z.cash/downloads/";
const int    kParamAttempts     = 3;                    // automatic tries per file before asking
const int    kParamRetryDelayMs = 5000;                 // pause between automatic tries
const int    kParamStallMs      = 60000;                // abort a part that receives nothing this long
const qint64 kParamSpaceMargin  = 64LL * 1024 * 1024;   // free space kept beyond the files

const ParamFile* findParamFile(const QString& name) {
    for (const auto& p : kParamFiles)
        if (name == p.name) return &p;
    return nullptr;
}

// A file whose SHA-256 matched is remembered in QSettings by size and modification time, so
// later starts compare the stamp instead of hashing 741 MiB again.
QString paramStampKey(const char* name) {
    return QString("params/verified/") + name;
}

QString paramStamp(const QFileInfo& fi) {
    return QString::number(fi.size()) + ":" + QString::number(fi.lastModified().toMSecsSinceEpoch());
}

bool paramStamped(const ParamFile& p, const QFileInfo& fi) {
    return fi.exists() && fi.size() == p.size &&
           QSettings().value(paramStampKey(p.name)).toString() == paramStamp(fi);
}

// SHA-256 of a file in 4 MiB reads, processing events between reads so the window stays
// responsive. Returns false and sets reason when the file cannot be read.
bool sha256File(const QString& path, QByteArray* hexOut, QString* reason) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        *reason = f.errorString();
        return false;
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    while (!f.atEnd()) {
        const QByteArray chunk = f.read(4 << 20);
        if (chunk.isEmpty() && f.error() != QFileDevice::NoError) {
            *reason = f.errorString();
            return false;
        }
        hash.addData(chunk);
        QCoreApplication::processEvents(QEventLoop::ExcludeUserInputEvents);
    }
    *hexOut = hash.result().toHex();
    return true;
}

// Move a file to NAME.bad, replacing an older one, or delete it; false if it is still there.
bool moveParamAside(const QString& path) {
    QFile::remove(path + ".bad");
    if (QFile::rename(path, path + ".bad"))
        return true;
    QFile::remove(path);
    return !QFile::exists(path);
}

} // namespace

bool ConnectionLoader::askRetryParams(const QString& message) {
    main->logger->write(message);
    if (Settings::getInstance()->isHeadless())
        return false;
    return QMessageBox::warning(main, QObject::tr("Proving parameters"),
               message + "\n\n" + QObject::tr("Retry now, or Cancel and start the wallet again later."),
               QMessageBox::Retry | QMessageBox::Cancel, QMessageBox::Retry) == QMessageBox::Retry;
}

void ConnectionLoader::downloadParams(std::function<void(void)> cb) {
    const QString dirPath = zcashParamsDir();
    QDir paramsDir(dirPath);
    if (!paramsDir.exists() || !QFileInfo(dirPath).isWritable()) {
        const QString msg = QObject::tr("Cannot create or write the parameter directory %1.").arg(dirPath);
        if (askRetryParams(msg)) cb(); else showError(msg);
        return;
    }

    // Fetch each file that is missing, of the wrong size, unreadable, or failed its SHA-256
    // check in verifyParams (all of which leave it unstamped); move such a file aside first.
    QStringList needed;
    qint64 neededBytes = 0;
    for (const auto& p : kParamFiles) {
        const QString path = paramsDir.filePath(p.name);
        QFileInfo fi(path);
        if (paramStamped(p, fi))
            continue;
        if (fi.exists()) {
            main->logger->write(QString(p.name) + " is unverified or the wrong size; moving it to " + p.name + ".bad");
            if (!moveParamAside(path)) {
                const QString msg = QObject::tr("Cannot move %1 aside. Remove it, then retry.").arg(path);
                if (askRetryParams(msg)) cb(); else showError(msg);
                return;
            }
        }
        needed << p.name;
        neededBytes += p.size;
    }

    const qint64 freeBytes = QStorageInfo(dirPath).bytesAvailable();
    if (freeBytes >= 0 && freeBytes < neededBytes + kParamSpaceMargin) {
        const QString msg = QObject::tr("The parameter directory %1 needs %2 MB free; %3 MB are available.")
                                .arg(dirPath).arg((neededBytes + kParamSpaceMargin) >> 20).arg(freeBytes >> 20);
        if (askRetryParams(msg)) cb(); else showError(msg);
        return;
    }

    main->logger->write("Adding params to download queue: " + needed.join(", "));
    delete downloadQueue;
    downloadQueue = new QQueue<QString>();
    for (const auto& n : needed)
        downloadQueue->enqueue(n);
    if (client == nullptr)
        client = new QNetworkAccessManager(main);
    downloadAttempt = 0;
    doNextDownload(cb);
}

void ConnectionLoader::doNextDownload(std::function<void(void)> cb) {
    if (downloadQueue->isEmpty()) {
        delete downloadQueue;
        downloadQueue = nullptr;
        client->deleteLater();
        client = nullptr;
        delete currentOutput;
        currentOutput = nullptr;
        delete currentHash;
        currentHash = nullptr;

        main->logger->write("All Downloads done");
        this->showInformation(QObject::tr("All Downloads Finished Successfully!"));
        cb();
        return;
    }

    const QString dl = QDir(zcashParamsDir()).filePath(downloadQueue->head() + ".dl");
    delete currentOutput;
    currentOutput = new QFile(dl);
    if (!currentOutput->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        paramDownloadFailed(cb, QObject::tr("cannot write %1: %2").arg(dl, currentOutput->errorString()), false);
        return;
    }
    delete currentHash;
    currentHash = new QCryptographicHash(QCryptographicHash::Sha256);
    currentWriteFailed = false;
    downloadParamPart(cb, 1);
}

void ConnectionLoader::downloadParamPart(std::function<void(void)> cb, int part) {
    const QString name = downloadQueue->head();
    const ParamFile* param = findParamFile(name);
    const int filesRemaining = downloadQueue->size() - 1;
    const QString partName = name + ".part." + QString::number(part);

    QNetworkRequest request(QUrl(QString(kParamsUrl) + partName));
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
#if (QT_VERSION >= QT_VERSION_CHECK(5, 15, 0))
    request.setTransferTimeout(kParamStallMs);
#endif
    main->logger->write("Downloading " + partName +
                        (downloadAttempt > 0 ? " (attempt " + QString::number(downloadAttempt + 1) + ")" : QString()));
    QNetworkReply* reply = client->get(request);
    currentDownload = reply;
    downloadTime.start();

    QObject::connect(reply, &QNetworkReply::downloadProgress, [=] (qint64 done, qint64 total) {
        double speed = done * 1000.0 / qMax<qint64>(downloadTime.elapsed(), 1);
        QString unit;
        if (speed < 1024) {
            unit = "bytes/sec";
        } else if (speed < 1024*1024) {
            speed /= 1024;
            unit = "kB/s";
        } else {
            speed /= 1024*1024;
            unit = "MB/s";
        }
        const QString of = total > 0 ? QString::number(total/1024/1024) + QObject::tr(" MB") : QObject::tr("unknown size");
        this->showInformation(
            QObject::tr("Downloading ") % name % QObject::tr(" (part %1 of 2)").arg(part) %
                (filesRemaining > 0 ? " ( +" % QString::number(filesRemaining) % QObject::tr(" more remaining )") : QString("")),
            QString::number(done/1024/1024) % QObject::tr(" MB of ") % of % QObject::tr(" at ") % QString::number(speed, 'f', 2) % " " % unit);
    });

    // Append each block to NAME.dl and the running hash; a write that fails aborts the part.
    auto takeData = [=] () {
        const QByteArray data = reply->readAll();
        if (currentWriteFailed || data.isEmpty())
            return;
        currentHash->addData(data);
        if (currentOutput->write(data) != data.size()) {
            currentWriteFailed = true;
            reply->abort();
        }
    };
    QObject::connect(reply, &QNetworkReply::readyRead, takeData);

    QObject::connect(reply, &QNetworkReply::finished, [=] () {
        if (reply->error() == QNetworkReply::NoError)
            takeData();
        const QNetworkReply::NetworkError err = reply->error();
        const QString errText = reply->errorString();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();
        currentDownload = nullptr;

        if (currentWriteFailed) {
            paramDownloadFailed(cb, QObject::tr("cannot write %1: %2").arg(currentOutput->fileName(), currentOutput->errorString()), false);
            return;
        }
        if (err != QNetworkReply::NoError) {
            paramDownloadFailed(cb, partName + ": " + errText, true);
            return;
        }
        if (status != 200 && status != 206) {
            paramDownloadFailed(cb, partName + QObject::tr(": HTTP status %1").arg(status), true);
            return;
        }
        main->logger->write("Finished downloading " + partName);
        if (part == 1) {
            downloadParamPart(cb, 2);
            return;
        }

        // Both parts are in NAME.dl: it replaces NAME only with the expected size and SHA-256.
        if (!currentOutput->flush()) {
            paramDownloadFailed(cb, QObject::tr("cannot write %1: %2").arg(currentOutput->fileName(), currentOutput->errorString()), false);
            return;
        }
        currentOutput->close();
        const QString dl = currentOutput->fileName();
        const qint64 size = QFileInfo(dl).size();
        const QByteArray hex = currentHash->result().toHex();
        if (param == nullptr || size != param->size || hex != QByteArray(param->sha256)) {
            paramDownloadFailed(cb, QObject::tr("%1: %2 bytes, expected %3; SHA-256 %4")
                                        .arg(name).arg(size).arg(param ? param->size : 0)
                                        .arg(param && hex == QByteArray(param->sha256) ? QObject::tr("matches") : QObject::tr("does not match")), true);
            return;
        }
        const QString out = QDir(zcashParamsDir()).filePath(name);
        QFile::remove(out);
        if (!QFile::rename(dl, out)) {
            paramDownloadFailed(cb, QObject::tr("cannot rename %1 to %2").arg(dl, out), false);
            return;
        }
        QSettings().setValue(paramStampKey(param->name), paramStamp(QFileInfo(out)));
        main->logger->write("Verified " + name);
        downloadQueue->dequeue();
        downloadAttempt = 0;
        doNextDownload(cb);
    });
}

// A failed file: remove its partial download, retry transient failures automatically, then ask.
// Cancel closes the connection dialog; the next start of the wallet downloads again.
void ConnectionLoader::paramDownloadFailed(std::function<void(void)> cb, const QString& reason, bool retryable) {
    if (currentOutput != nullptr) {
        currentOutput->close();
        QFile::remove(currentOutput->fileName());
    }
    main->logger->write("Param download failed: " + reason);

    if (retryable && ++downloadAttempt < kParamAttempts) {
        main->logger->write("Retrying in " + QString::number(kParamRetryDelayMs / 1000) + " s");
        showInformation(QObject::tr("Download interrupted; retrying"), reason);
        QTimer::singleShot(kParamRetryDelayMs, main, [=]() { this->doNextDownload(cb); });
        return;
    }
    downloadAttempt = 0;
    if (askRetryParams(QObject::tr("Downloading the proving parameters failed:\n%1\n\nParameter directory: %2")
                           .arg(reason, zcashParamsDir()))) {
        doNextDownload(cb);
        return;
    }
    delete downloadQueue;
    downloadQueue = nullptr;
    if (client != nullptr) {
        client->deleteLater();
        client = nullptr;
    }
    showError(QObject::tr("The proving parameters are incomplete, so zerod cannot start. "
                          "The wallet downloads them again at its next start."));
}

bool ConnectionLoader::startEmbeddedZcashd() {
    if (!Settings::getInstance()->useEmbedded())
        return false;

    main->logger->write("Trying to start embedded zerod");

    // Static because it needs to survive even after this method returns.
    static QString processStdErrOutput;

    if (ezcashd != nullptr) {
        if (ezcashd->state() == QProcess::NotRunning) {
            if (!processStdErrOutput.isEmpty()) {
                QMessageBox::critical(main, QObject::tr("zerod error"), "reported: " + processStdErrOutput,
                                      QMessageBox::Ok);
            }
            return false;
        } else {
            return true;
        }
    }

    // Finally, start zerod
    QDir appPath(QCoreApplication::applicationDirPath());
#ifdef Q_OS_LINUX
    auto zcashdProgram = appPath.absoluteFilePath("zerod");
#elif defined(Q_OS_DARWIN)
    auto zcashdProgram = appPath.absoluteFilePath("zerod");
#else
    auto zcashdProgram = appPath.absoluteFilePath("zerod.exe");
#endif

    if (!QFile::exists(zcashdProgram)) {
        // qDebug() << "Can't find zerod at " << zcashdProgram;  // suppressed in release (message handler in main.cpp); uncomment to debug
        main->logger->write("Can't find zerod at " + zcashdProgram);
        return false;
    }

    ezcashd = new QProcess(main);
    QObject::connect(ezcashd, &QProcess::started, [=] () {
        //qDebug() << "zerod started";
    });

    QObject::connect(ezcashd, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                        [=](int, QProcess::ExitStatus) {
        //qDebug() << "zerod finished with code " << exitCode << "," << exitStatus;
    });

    QObject::connect(ezcashd, &QProcess::errorOccurred, [&] (auto) {
        //qDebug() << "Couldn't start zerod: " << error;
    });

    QObject::connect(ezcashd, &QProcess::readyReadStandardError, [=]() {
        auto output = ezcashd->readAllStandardError();
       main->logger->write("zerod stderr:" + output);
        processStdErrOutput.append(output);
    });

#ifdef Q_OS_LINUX
    ezcashd->start(zcashdProgram, QStringList());
#elif defined(Q_OS_DARWIN)
    ezcashd->start(zcashdProgram, QStringList());
#else
    ezcashd->setWorkingDirectory(appPath.absolutePath());
    ezcashd->start(zcashdProgram, QStringList());
#endif // Q_OS_LINUX


    return true;
}

void ConnectionLoader::doManualConnect() {
    auto config = loadFromSettings();

    if (!config) {
        // Nothing configured, show an error
        QString explanation = QString()
                % QObject::tr("A manual connection was requested, but the settings are not configured.\n\n"
                "Please set the host/port and user/password in the Edit->Settings menu.");

        showError(explanation);
        doRPCSetConnection(nullptr);

        return;
    }

    auto connection = makeConnection(config);
    refreshZcashdState(connection, [=] () {
        QString explanation = QString()
                % QObject::tr("Could not connect to zerod configured in settings.\n\n"
                "Please set the host/port and user/password in the Edit->Settings menu.");

        showError(explanation);
        doRPCSetConnection(nullptr);

        return;
    });
}

void ConnectionLoader::doRPCSetConnection(Connection* conn) {
    rpc->setEZcashd(ezcashd);
    rpc->setConnection(conn);

    d->accept();

    delete this;
}

Connection* ConnectionLoader::makeConnection(std::shared_ptr<ConnectionConfig> config) {
    QNetworkAccessManager* client = new QNetworkAccessManager(main);

    QUrl myurl;
    myurl.setScheme("http");
    myurl.setHost(config.get()->host);
    myurl.setPort(config.get()->port.toInt());

    QNetworkRequest* request = new QNetworkRequest();
    request->setUrl(myurl);
    request->setHeader(QNetworkRequest::ContentTypeHeader, "text/plain");

    QString userpass = config.get()->rpcuser % ":" % config.get()->rpcpassword;
    QString headerData = "Basic " + userpass.toLocal8Bit().toBase64();
    request->setRawHeader("Authorization", headerData.toLocal8Bit());

    return new Connection(main, client, request, config);
}

void ConnectionLoader::refreshZcashdState(Connection* connection, std::function<void(void)> refused) {
    json payload = {
        {"jsonrpc", "1.0"},
        {"id", "someid"},
        {"method", "getinfo"}
    };
    connection->doRPC(payload,
        [=] (auto) {
            // Success, hide the dialog if it was shown.
            d->hide();
            main->logger->write("zerod is online.");
            this->doRPCSetConnection(connection);
        },
        [=] (auto reply, auto res) {
            auto err = reply->error();
            if (err == QNetworkReply::NetworkError::ConnectionRefusedError) {
                refused();
            } else if (err == QNetworkReply::NetworkError::AuthenticationRequiredError) {
                main->logger->write("Authentication failed");
                QString explanation = QString() %
                        QObject::tr("Authentication failed. The username / password you specified was "
                        "not accepted by zerod. Try changing it in the Edit->Settings menu");

                this->showError(explanation);
            } else if (err == QNetworkReply::NetworkError::InternalServerError &&
                    !res.is_discarded()) {
                // The server is loading, so just poll until it succeeds
                QString status      = QString::fromStdString(res["error"]["message"]);
                {
                    static int dots = 0;
                    status = status.left(status.length() - 3) + QString(".").repeated(dots);
                    dots++;
                    if (dots > 3)
                        dots = 0;
                }
                this->showInformation(QObject::tr("Your zerod is starting up. Please wait."), status);
                main->logger->write("Waiting for zerod to come online.");
                // 5s: warmup can take minutes; 1s retries pile onto an overloaded RPC queue
                QTimer::singleShot(5000, [=]() { this->refreshZcashdState(connection, refused); });
            }
        }
    );
}

// Update the UI with the status
void ConnectionLoader::showInformation(QString info, QString detail) {
    static int rescanCount = 0;
    if (detail.toLower().startsWith("rescan")) {
        rescanCount++;
    }

    if (rescanCount > 10) {
        detail = detail + "\n" + QObject::tr("This may take several hours");
    }

    connD->status->setText(info);
    connD->statusDetail->setText(detail);

    if (rescanCount < 10)
        main->logger->write(info + ":" + detail);
}

/**
 * Show error will close the loading dialog and show an error.
*/
void ConnectionLoader::showError(QString explanation) {
    rpc->setEZcashd(nullptr);
    rpc->noConnection();

    QMessageBox::critical(main, QObject::tr("Connection Error"), explanation, QMessageBox::Ok);
    d->close();
}

QString ConnectionLoader::locateZcashConfFile() {
#ifdef Q_OS_LINUX
    auto confLocation = QStandardPaths::locate(QStandardPaths::HomeLocation, ".zero/zero.conf");
#elif defined(Q_OS_DARWIN)
    auto confLocation = QStandardPaths::locate(QStandardPaths::HomeLocation, "Library/Application Support/Zero/zero.conf");
#else
    auto confLocation = QStandardPaths::locate(QStandardPaths::AppDataLocation, "../../zero/zero.conf");
#endif

    main->logger->write("Found zero.conf at " + QDir::cleanPath(confLocation));
    return QDir::cleanPath(confLocation);
}

QString ConnectionLoader::zcashConfWritableLocation() {
#ifdef Q_OS_LINUX
    auto confLocation = QDir(QStandardPaths::writableLocation(QStandardPaths::HomeLocation)).filePath(".zero/zero.conf");
#elif defined(Q_OS_DARWIN)
    auto confLocation = QDir(QStandardPaths::writableLocation(QStandardPaths::HomeLocation)).filePath("Library/Application Support/Zero/zero.conf");
#else
    auto confLocation = QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)).filePath("../../zero/zero.conf");
#endif

    main->logger->write("Found zero.conf at " + QDir::cleanPath(confLocation));
    return QDir::cleanPath(confLocation);
}

QString ConnectionLoader::zcashParamsDir() {
    #ifdef Q_OS_LINUX
    auto paramsLocation = QDir(QDir(QStandardPaths::writableLocation(QStandardPaths::HomeLocation)).filePath(".zcash-params"));
#elif defined(Q_OS_DARWIN)
    auto paramsLocation = QDir(QDir(QStandardPaths::writableLocation(QStandardPaths::HomeLocation)).filePath("Library/Application Support/ZcashParams"));
#else
    auto paramsLocation = QDir(QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)).filePath("../../ZcashParams"));
#endif

    if (!paramsLocation.exists()) {
        main->logger->write("Creating params location at " + paramsLocation.absolutePath());
        if (!QDir().mkpath(paramsLocation.absolutePath()))
            main->logger->write("Cannot create " + paramsLocation.absolutePath());
    }

    main->logger->write("Found Zcash params directory at " + paramsLocation.absolutePath());
    return paramsLocation.absolutePath();
}

bool ConnectionLoader::verifyParams() {
    QDir paramsDir(zcashParamsDir());
    QSettings settings;
    bool ok = true;

    // Each file zerod loads must exist at its expected size. Its SHA-256 is checked once and
    // stamped; a file that cannot be read or fails the check is left unstamped, and
    // downloadParams moves it aside and downloads it again. Every file is checked, so a
    // missing first file does not cause later good files to be fetched again.
    for (const auto& p : kParamFiles) {
        const QString path = paramsDir.filePath(p.name);
        QFileInfo fi(path);
        if (!fi.exists() || fi.size() != p.size) {
            ok = false;
            continue;
        }
        if (paramStamped(p, fi))
            continue;

        showInformation(QObject::tr("Checking ") + p.name, QObject::tr("SHA-256 of an existing parameter file"));
        QByteArray hex;
        QString reason;
        if (!sha256File(path, &hex, &reason)) {
            main->logger->write("Cannot read " + path + ": " + reason);
            ok = false;
            continue;
        }
        if (hex != QByteArray(p.sha256)) {
            main->logger->write(QString(p.name) + " failed its SHA-256 check");
            settings.remove(paramStampKey(p.name));
            ok = false;
            continue;
        }
        settings.setValue(paramStampKey(p.name), paramStamp(fi));
        main->logger->write("Verified " + QString(p.name));
    }
    return ok;
}

/**
 * Try to automatically detect a zero.conf file in the correct location and load parameters
 */
std::shared_ptr<ConnectionConfig> ConnectionLoader::autoDetectZcashConf() {
    auto confLocation = Settings::getInstance()->getZcashdConfLocation();

    if (confLocation.isEmpty()) {
        confLocation = locateZcashConfFile();
    }

    if (confLocation.isNull()) {
        // No Zero file, just return with nothing
        return nullptr;
    }

    QFile file(confLocation);
    if (!file.open(QIODevice::ReadOnly)) {
        // qDebug() << file.errorString();  // suppressed in release (message handler in main.cpp); uncomment to debug
        return nullptr;
    }

    QTextStream in(&file);

    auto zcashconf = new ConnectionConfig();
    zcashconf->host     = "127.0.0.1";
    zcashconf->connType = ConnectionType::DetectedConfExternalZcashD;
    zcashconf->usingZcashConf = true;
    zcashconf->zcashDir = QFileInfo(confLocation).absoluteDir().absolutePath();
    zcashconf->zcashDaemon = false;

    Settings::getInstance()->setUsingZcashConf(confLocation);

    while (!in.atEnd()) {
        QString line = in.readLine();
        auto s = line.indexOf("=");
        QString name  = line.left(s).trimmed().toLower();
        QString value = line.right(line.length() - s - 1).trimmed();

        if (name == "rpcuser") {
            zcashconf->rpcuser = value;
        }
        if (name == "rpcpassword") {
            zcashconf->rpcpassword = value;
        }
        if (name == "rpcport") {
            zcashconf->port = value;
        }
        if (name == "daemon" && value == "1") {
            zcashconf->zcashDaemon = true;
        }
        if (name == "proxy") {
            zcashconf->proxy = value;
        }
        if (name == "safekey") {
            zcashconf->safenode = value;
        }
        if (name == "spentindex") {
            zcashconf->spentindex = value;
        }
        if (name == "timestampindex") {
            zcashconf->timeindex = value;
        }
        if (name == "addressindex") {
            zcashconf->addrindex = value;
        }
        if (name == "testnet" &&
            value == "1"  &&
            zcashconf->port.isEmpty()) {
                zcashconf->port = "23812";
        }

        if (name == "deletetx") {
            zcashconf->deletetx = value;
        }
        if (name == "consolidation") {
            zcashconf->consolidation = value;
        }

        if (name == "consolidationtxfee") {
            zcashconf->consolidationtxfee = value;
        }

        if (name == "consolidatesaplingaddress") {
            zcashconf->consolidationAddresses.push_back(value);
        }

    }

    // If rpcport is not in the file, and it was not set by the testnet=1 flag, then go to default
    if (zcashconf->port.isEmpty()) zcashconf->port = "23811";
    file.close();

    // In addition to the zero.conf file, also double check the params.

    return std::shared_ptr<ConnectionConfig>(zcashconf);
}

/**
 * Load connection settings from the UI, which indicates an unknown, external zerod
 */
std::shared_ptr<ConnectionConfig> ConnectionLoader::loadFromSettings() {
    // Load from the QT Settings.
    QSettings s;

    auto host                         = s.value("connection/host").toString();
    auto port                         = s.value("connection/port").toString();
    auto username                     = s.value("connection/rpcuser").toString();
    auto password                     = s.value("connection/rpcpassword").toString();
    auto deletetx                     = s.value("connection/deletetx").toString();
    auto consolidation                = s.value("connection/consolidation").toString();
    auto consolidationtxfee           = s.value("connection/consolidationtxfee").toString();
    auto consolidationAddressesTemp   = s.value("connection/consolidationAddresses").toString();

    QStringList list = consolidationAddressesTemp.split(",");
    QList<QString> consolidationAddresses;
    for (int i = 0; i < list.size(); ++i) {
        consolidationAddresses.push_back(list[i]);
    }

    if (username.isEmpty() || password.isEmpty())
        return nullptr;

    auto uiConfig = new ConnectionConfig{ host, port, username, password, false, false, false, "", "", "", "", "", "", deletetx, consolidation, consolidationtxfee, consolidationAddresses, ConnectionType::UISettingsZCashD};

    return std::shared_ptr<ConnectionConfig>(uiConfig);
}





/***********************************************************************************
 *  Connection Class
 ************************************************************************************/
Connection::Connection(MainWindow* m, QNetworkAccessManager* c, QNetworkRequest* r,
                        std::shared_ptr<ConnectionConfig> conf) {
    this->restclient  = c;
    this->request     = r;
    this->config      = conf;
    this->main        = m;
}

Connection::~Connection() {
    delete restclient;
    delete request;
}

void Connection::doRPC(const json& payload, const std::function<void(json)>& cb,
                       const std::function<void(QNetworkReply*, const json&)>& ne) {
    if (shutdownInProgress) {
        // Ignoring RPC because shutdown in progress
        return;
    }

    // Uncomment to trace requests in a debug build; release builds drop qDebug output.
    // qDebug() << "RPC: " << QString::fromStdString(payload["method"]);
    // qDebug() << "< payload " << QString::fromStdString(payload.dump());

    QNetworkReply *reply = restclient->post(*request, QByteArray::fromStdString(payload.dump()));

    QObject::connect(reply, &QNetworkReply::finished, [=] {
        reply->deleteLater();
        if (shutdownInProgress) {
            // Ignoring callback because shutdown in progress
            return;
        }

        if (reply->error() != QNetworkReply::NoError) {
            auto parsed = json::parse(reply->readAll(), nullptr, false);
            ne(reply, parsed);

            return;
        }

        auto parsed = json::parse(reply->readAll(), nullptr, false);
        if (parsed.is_discarded() || !parsed.is_object()) {
            ne(reply, json::object());
            return;
        }
        if (parsed.contains("error") && !parsed["error"].is_null()) {
            ne(reply, parsed);
            return;
        }

        cb(parsed["result"]);
    });
}

void Connection::doRPCWithDefaultErrorHandling(const json& payload, const std::function<void(json)>& cb) {
    doRPC(payload, cb, [=] (auto reply, auto parsed) {
        if (!parsed.is_discarded() && !parsed["error"]["message"].is_null()) {
            this->showTxError(QString::fromStdString(parsed["error"]["message"]));
        } else {
            this->showTxError(reply->errorString());
        }
    });
}

static bool isSoftRpcDataContinue(QNetworkReply* reply, const json& parsed, QString* reasonOut, int* codeOut, int* httpOut) {
    // Soft set: statusBar / yellow icon only -- not Transaction Error, not Connection Error.
    const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (httpOut)
        *httpOut = http;
    if (codeOut)
        *codeOut = 0;

    if (http == 503) {
        if (reasonOut)
            *reasonOut = QObject::tr("Delay in getting node status: RPC work queue full (503)");
        return true;
    }
    if (reply->error() == QNetworkReply::TimeoutError
        || reply->error() == QNetworkReply::OperationCanceledError) {
        if (reasonOut)
            *reasonOut = QObject::tr("Delay in getting node status: RPC timeout");
        return true;
    }

    if (parsed.is_discarded() || !parsed.is_object())
        return false;
    if (!parsed.contains("error") || parsed["error"].is_null() || !parsed["error"].is_object())
        return false;
    const auto& err = parsed["error"];
    if (!err.contains("code") || !err["code"].is_number_integer())
        return false;
    const int code = err["code"].get<int>();
    if (codeOut)
        *codeOut = code;
    // -34 RPC_DATA_CONTINUE; -28 warmup; -31 witnesses; -33 witness cache
    if (code == -34 || code == -28 || code == -31 || code == -33) {
        if (reasonOut) {
            if (code == -34)
                *reasonOut = QObject::tr("Delay in getting node status: rpc_data_continue (-34)");
            else if (code == -28)
                *reasonOut = QObject::tr("Delay in getting node status: node warming up");
            else if (code == -31)
                *reasonOut = QObject::tr("Delay in getting node status: witnesses not ready");
            else
                *reasonOut = QObject::tr("Delay in getting node status: building witness cache");
        }
        return true;
    }
    return false;
}

void Connection::doRPCSoftDataContinue(const json& payload, const std::function<void(json)>& cb) {
    // Sticky soft UI: show queue/warmup/timeout once until a successful getalldata.
    // -34 rpc_data_continue: message every time (expected rare; useful while validating).
    static bool s_queueFullNotified = false;
    static bool s_notReadyNotified = false;
    static bool s_timeoutNotified = false;
    static bool s_softYellowIcon = false;

    auto clearSoftDegraded = [this]() {
        s_queueFullNotified = false;
        s_notReadyNotified = false;
        s_timeoutNotified = false;
        if (s_softYellowIcon && main && main->statusIcon) {
            QIcon i(":/icons/res/connected.gif");
            main->statusIcon->setPixmap(i.pixmap(16, 16));
            s_softYellowIcon = false;
        }
    };

    doRPC(payload,
        [=](json result) {
            clearSoftDegraded();
            cb(result);
        },
        [=](auto reply, auto parsed) {
            QString softReason;
            int code = 0;
            int http = 0;
            if (!isSoftRpcDataContinue(reply, parsed, &softReason, &code, &http)) {
                // Hard failure on a status poll -- not a send, not a disconnect.
                if (!parsed.is_discarded() && parsed.contains("error")
                    && !parsed["error"].is_null()
                    && parsed["error"].contains("message")
                    && !parsed["error"]["message"].is_null()) {
                    this->showStatusError(QString::fromStdString(parsed["error"]["message"]));
                } else {
                    this->showStatusError(reply->errorString());
                }
                return;
            }

            bool showMsg = false;
            bool setYellow = false;
            if (code == -34) {
                // Each time while validating coalesce behavior
                showMsg = true;
            } else if (http == 503) {
                if (!s_queueFullNotified) {
                    showMsg = true;
                    s_queueFullNotified = true;
                    setYellow = true;
                }
            } else if (reply->error() == QNetworkReply::TimeoutError
                       || reply->error() == QNetworkReply::OperationCanceledError) {
                if (!s_timeoutNotified) {
                    showMsg = true;
                    s_timeoutNotified = true;
                    setYellow = true;
                }
            } else if (code == -28 || code == -31 || code == -33) {
                if (!s_notReadyNotified) {
                    showMsg = true;
                    s_notReadyNotified = true;
                    setYellow = true;
                }
            }

            if (main) {
                if (showMsg)
                    main->statusBar()->showMessage(softReason, 5000);
                if (main->statusLabel)
                    main->statusLabel->setToolTip(softReason);
                if (main->statusIcon) {
                    main->statusIcon->setToolTip(softReason);
                    if (setYellow) {
                        // Same warning pixmap as 0-peers; tooltip = "Delay in getting node status: ..."
                        QIcon i = QApplication::style()->standardIcon(QStyle::SP_MessageBoxWarning);
                        main->statusIcon->setPixmap(i.pixmap(16, 16));
                        s_softYellowIcon = true;
                    }
                }
            }
        });
}

void Connection::doRPCIgnoreError(const json& payload, const std::function<void(json)>& cb) {
    doRPC(payload, cb, [=] (auto, auto) {
        // Ignored error handling
    });
}

void invokeRpcCallbackSafe(const std::function<void(const json&)>& cb, const json& reply) {
    try {
        if (reply.is_null()) {
            return;
        }
        cb(reply);
    } catch (...) {
        qDebug() << "RPC callback exception (result ignored)";
    }
}

void Connection::doRPCIgnoreErrorSafe(const json& payload, const std::function<void(const json&)>& cb) {
    doRPCIgnoreError(payload, [=](const json& reply) {
        invokeRpcCallbackSafe(cb, reply);
    });
}

void Connection::showTxError(const QString& error) {
    if (error.isNull()) return;

    // Prevent multiple dialog boxes from showing, because they're all called async
    static bool shown = false;
    if (shown)
        return;

    shown = true;
    QMessageBox::critical(main, QObject::tr("Transaction Error"), QObject::tr("There was an error sending the transaction. The error was:") + "\n\n"
        + error, QMessageBox::StandardButton::Ok);
    shown = false;
}

void Connection::showStatusError(const QString& error) {
    if (error.isNull()) return;

    static bool shown = false;
    if (shown)
        return;

    shown = true;
    QMessageBox::warning(main, QObject::tr("Delay in getting node status"),
        QObject::tr("There was a delay in getting node status. Last balances and history were kept. Detail:")
            + "\n\n" + error,
        QMessageBox::StandardButton::Ok);
    shown = false;
}

void Connection::showConnectionError(const QString& error) {
    if (error.isNull()) return;

    static bool shown = false;
    if (shown)
        return;

    shown = true;
    QMessageBox::critical(main, QObject::tr("Connection Error"),
        QObject::tr("There was an error connecting to zerod. The error was:") + "\n\n" + error,
        QMessageBox::StandardButton::Ok);
    shown = false;
}

/**
 * Prevent all future calls from going through
 */
void Connection::shutdown() {
    shutdownInProgress = true;
}
