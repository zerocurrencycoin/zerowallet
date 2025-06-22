#include "mainwindow.h"
#include "addressbook.h"
#include "viewalladdresses.h"
#include "validateaddress.h"
#include "ui_mainwindow.h"
#include "ui_mobileappconnector.h"
#include "ui_addressbook.h"
#include "ui_zboard.h"
#include "ui_privkey.h"
#include "ui_about.h"
#include "ui_settings.h"
#include "ui_turnstile.h"
#include "ui_turnstileprogress.h"
#include "ui_viewalladdresses.h"
#include "ui_validateaddress.h"
#include "ui_znsetup.h"
#include "rpc.h"
#include "balancestablemodel.h"
#include "settings.h"
#include "version.h"
#include "turnstile.h"
#include "connection.h"
#include "requestdialog.h"
#include "websockets.h"

using json = nlohmann::json;

MainWindow::MainWindow(QWidget *parent) :
    QMainWindow(parent),
    ui(new Ui::MainWindow)
{

	// Include css
    QString theme_name;
    try
    {
       theme_name = Settings::getInstance()->get_theme_name();
    }
    catch (...)
    {
        theme_name = "default";
    }

    QFile qFile(":/css/res/css/" + theme_name +".css");
    if (qFile.open(QFile::ReadOnly))
    {
      QString styleSheet = QLatin1String(qFile.readAll());
      this->setStyleSheet(styleSheet);
    }


    ui->setupUi(this);
    logger = new Logger(this, QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)).filePath("zero-qt-wallet.log"));

    // Status Bar
    setupStatusBar();

    // Settings editor
    setupSettingsModal();

    // Set up exit action
    QObject::connect(ui->actionExit, &QAction::triggered, this, &MainWindow::close);

    // Set up donate action
    QObject::connect(ui->actionDonate, &QAction::triggered, this, &MainWindow::donate);

    QObject::connect(ui->actionDiscord, &QAction::triggered, this, &MainWindow::discord);

    QObject::connect(ui->actionWebsite, &QAction::triggered, this, &MainWindow::website);

    // QObject::connect(ui->actionSafeNodes, &QAction::triggered, this, &MainWindow::safenodes);

    // File a bug
    QObject::connect(ui->actionFile_a_bug, &QAction::triggered, [=]() {
        QDesktopServices::openUrl(QUrl("https://github.com/zerocurrencycoin/zerowallet/issues/new"));
    });

    // Set up check for updates action
    QObject::connect(ui->actionCheck_for_Updates, &QAction::triggered, [=] () {
        // Silent is false, so show notification even if no update was found
        rpc->checkForUpdate(false);
    });

    // Recurring payments
    QObject::connect(ui->action_Recurring_Payments, &QAction::triggered, [=]() {
        Recurring::getInstance()->showRecurringDialog(this);
    });

    // Request zero
    QObject::connect(ui->actionRequest_zcash, &QAction::triggered, [=]() {
        RequestDialog::showRequestZcash(this);
    });

    // Pay Zero URI
    QObject::connect(ui->actionPay_URI, &QAction::triggered, [=] () {
        payZcashURI();
    });

    // Import Private Key
    QObject::connect(ui->actionImport_Private_Key, &QAction::triggered, this, &MainWindow::importPrivKey);

    // Export All Private Keys
    QObject::connect(ui->actionExport_All_Private_Keys, &QAction::triggered, this, &MainWindow::exportAllKeys);

    // Backup wallet.zero
    QObject::connect(ui->actionBackup_wallet_dat, &QAction::triggered, this, &MainWindow::backupWalletDat);

    // Export transactions
    QObject::connect(ui->actionExport_transactions, &QAction::triggered, this, &MainWindow::exportTransactions);

/*
    // z-Board.net
    QObject::connect(ui->actionz_board_net, &QAction::triggered, this, &MainWindow::postToZBoard);
*/

    // Validate Address
    QObject::connect(ui->actionValidate_Address, &QAction::triggered, this, &MainWindow::validateAddress);

/*    // Connect mobile app
    QObject::connect(ui->actionConnect_Mobile_App, &QAction::triggered, this, [=] () {
        if (rpc->getConnection() == nullptr)
            return;

        AppDataServer::getInstance()->connectAppDialog(this);
    });
*/

    // Address Book
    QObject::connect(ui->action_Address_Book, &QAction::triggered, this, &MainWindow::addressBook);

    // Set up about action
    QObject::connect(ui->actionAbout, &QAction::triggered, [=] () {
        QDialog aboutDialog(this);
        Ui_about about;
        about.setupUi(&aboutDialog);
        Settings::saveRestore(&aboutDialog);

        QString version    = QString("Version ") % QString(APP_VERSION) % " (" % QString(__DATE__) % ")";
        about.versionLabel->setText(version);

        aboutDialog.exec();
    });

    // Initialize to the balances tab
    ui->tabWidget->setCurrentIndex(0);

    // The zerod tab is hidden by default, and only later added in if the embedded zerod is started
    zcashdtab = ui->tabWidget->widget(4);
    //ui->tabWidget->removeTab(4);

    // The safenodes tab is hidden by default, and only later added in if the embedded zerod is started
    zeronodestab = ui->tabWidget->widget(3);
    // ui->tabWidget->removeTab(3);

    setupSendTab();
    setupTransactionsTab();
    setupReceiveTab();
    setupBalancesTab();
//    setupTurnstileDialog();
    setupZcashdTab();
    setupZNodesTab();
//    SafeNodesTab();

    rpc = new RPC(this);

    restoreSavedStates();

    if (AppDataServer::getInstance()->isAppConnected()) {
        auto ads = AppDataServer::getInstance();

        QString wormholecode = "";
        if (ads->getAllowInternetConnection())
            wormholecode = ads->getWormholeCode(ads->getSecretHex());

        createWebsocket(wormholecode);
    }
}

void MainWindow::createWebsocket(QString wormholecode) {
    qDebug() << "Listening for app connections on port 8237";
    // Create the websocket server, for listening to direct connections
    wsserver = new WSServer(8237, false, this);

    if (!wormholecode.isEmpty()) {
        // Connect to the wormhole service
        wormhole = new WormholeClient(this, wormholecode);
    }
}

void MainWindow::stopWebsocket() {
    delete wsserver;
    wsserver = nullptr;

    delete wormhole;
    wormhole = nullptr;

    qDebug() << "Websockets for app connections shut down";
}

bool MainWindow::isWebsocketListening() {
    return wsserver != nullptr;
}

void MainWindow::replaceWormholeClient(WormholeClient* newClient) {
    delete wormhole;
    wormhole = newClient;
}

void MainWindow::restoreSavedStates() {
    QSettings s;
    restoreGeometry(s.value("geometry").toByteArray());

    ui->balancesOverviewTable->horizontalHeader()->restoreState(s.value("balovertablegeometry").toByteArray());
    ui->balancesTable->horizontalHeader()->restoreState(s.value("baltablegeometry").toByteArray());

    ui->transactionsTable->horizontalHeader()->restoreState(s.value("tratablegeometry").toByteArray());

    // Explicitly set the tx table resize headers, since some previous values may have made them
    // non-expandable.
    ui->transactionsTable->horizontalHeader()->setSectionResizeMode(3, QHeaderView::Interactive);
    ui->transactionsTable->horizontalHeader()->setSectionResizeMode(4, QHeaderView::Interactive);

    ui->tableZeroNodeGlobal->horizontalHeader()->restoreState(s.value("gzntablegeometry").toByteArray());
    ui->tableZeroNodeLocal->horizontalHeader()->restoreState(s.value("lzntablegeometry").toByteArray());
}

void MainWindow::doClose() {
    closeEvent(nullptr);
}

void MainWindow::closeEvent(QCloseEvent* event) {
    QSettings s;

    s.setValue("geometry", saveGeometry());
    s.setValue("balovertablegeometry", ui->balancesOverviewTable->horizontalHeader()->saveState());
    s.setValue("baltablegeometry", ui->balancesTable->horizontalHeader()->saveState());
    s.setValue("tratablegeometry", ui->transactionsTable->horizontalHeader()->saveState());
    s.setValue("gzntablegeometry", ui->tableZeroNodeGlobal->horizontalHeader()->saveState());
    s.setValue("lzntablegeometry", ui->tableZeroNodeLocal->horizontalHeader()->saveState());

    s.sync();

    // Let the RPC know to shut down any running service.
    rpc->shutdownZcashd();

    // Bubble up
    if (event)
        QMainWindow::closeEvent(event);
}

void MainWindow::turnstileProgress() {
    Ui_TurnstileProgress progress;
    QDialog d(this);
    progress.setupUi(&d);
    Settings::saveRestore(&d);

    QIcon icon = QApplication::style()->standardIcon(QStyle::SP_MessageBoxWarning);
    progress.msgIcon->setPixmap(icon.pixmap(64, 64));

    bool migrationFinished = false;
    auto fnUpdateProgressUI = [=, &migrationFinished] () mutable {
        // Get the plan progress
        if (rpc->getTurnstile()->isMigrationPresent()) {
            auto curProgress = rpc->getTurnstile()->getPlanProgress();

            progress.progressTxt->setText(QString::number(curProgress.step) % QString(" / ") % QString::number(curProgress.totalSteps));
            progress.progressBar->setValue(100 * curProgress.step / curProgress.totalSteps);

            auto nextTxBlock = curProgress.nextBlock - Settings::getInstance()->getBlockNumber();

            progress.fromAddr->setText(curProgress.from);
            progress.toAddr->setText(curProgress.to);

            if (curProgress.step == curProgress.totalSteps) {
                migrationFinished = true;
                auto txt = QString("Turnstile migration finished");
                if (curProgress.hasErrors) {
                    txt = txt + ". There were some errors.\n\nYour funds are all in your wallet, so you should be able to finish moving them manually.";
                }
                progress.nextTx->setText(txt);
            } else {
                progress.nextTx->setText(QString("Next transaction in ")
                                    % QString::number(nextTxBlock < 0 ? 0 : nextTxBlock)
                                    % " blocks via " % curProgress.via % "\n"
                                    % (nextTxBlock <= 0 ? "(waiting for confirmations)" : ""));
            }

        } else {
            progress.progressTxt->setText("");
            progress.progressBar->setValue(0);
            progress.nextTx->setText("No turnstile migration is in progress");
        }
    };

    QTimer progressTimer(this);
    QObject::connect(&progressTimer, &QTimer::timeout, fnUpdateProgressUI);
    progressTimer.start(Settings::updateSpeed);
    fnUpdateProgressUI();

    auto curProgress = rpc->getTurnstile()->getPlanProgress();

    // Abort button
    if (curProgress.step != curProgress.totalSteps)
        progress.buttonBox->button(QDialogButtonBox::Discard)->setText("Abort");
    else
        progress.buttonBox->button(QDialogButtonBox::Discard)->setVisible(false);

    // Abort button clicked
    QObject::connect(progress.buttonBox->button(QDialogButtonBox::Discard), &QPushButton::clicked, [&] () {
        if (curProgress.step != curProgress.totalSteps) {
            auto abort = QMessageBox::warning(this, "Are you sure you want to Abort?",
                                    "Are you sure you want to abort the migration?\nAll further transactions will be cancelled.\nAll your funds are still in your wallet.",
                                    QMessageBox::Yes, QMessageBox::No);
            if (abort == QMessageBox::Yes) {
                rpc->getTurnstile()->removeFile();
                d.close();
                ui->statusBar->showMessage("Automatic Sapling turnstile migration aborted.");
            }
        }
    });

    d.exec();
    if (migrationFinished || curProgress.step == curProgress.totalSteps) {
        // Finished, so delete the file
        rpc->getTurnstile()->removeFile();
    }
}

void MainWindow::turnstileDoMigration(QString fromAddr) {
    // Return if there is no connection
    if (rpc->getAllZAddresses() == nullptr || rpc->getAllBalances() == nullptr) {
        QMessageBox::information(this, tr("Not yet ready"), tr("zerod is not yet ready. Please wait for the UI to load"), QMessageBox::Ok);
        return;
    }

    // If a migration is already in progress, show the progress dialog instead
    if (rpc->getTurnstile()->isMigrationPresent()) {
        turnstileProgress();
        return;
    }

    Ui_Turnstile turnstile;
    QDialog d(this);
    turnstile.setupUi(&d);
    Settings::saveRestore(&d);

    QIcon icon = QApplication::style()->standardIcon(QStyle::SP_MessageBoxInformation);
    turnstile.msgIcon->setPixmap(icon.pixmap(64, 64));

    auto fnGetAllSproutBalance = [=] () {
        double bal = 0;
        for (auto addr : *rpc->getAllZAddresses()) {
            if (Settings::getInstance()->isSproutAddress(addr) && rpc->getAllBalances()) {
                bal += rpc->getAllBalances()->value(addr);
            }
        }

        return bal;
    };

    turnstile.fromBalance->setText(Settings::getZECUSDDisplayFormat(fnGetAllSproutBalance()));
    for (auto addr : *rpc->getAllZAddresses()) {
        auto bal = rpc->getAllBalances()->value(addr);
        if (Settings::getInstance()->isSaplingAddress(addr)) {
            turnstile.migrateTo->addItem(addr, bal);
        } else {
            turnstile.migrateZaddList->addItem(addr, bal);
        }
    }

    auto fnUpdateSproutBalance = [=] (QString addr) {
        double bal = 0;

        // The currentText contains the balance as well, so strip that.
        if (addr.contains("(")) {
            addr = addr.left(addr.indexOf("("));
        }

        if (addr.startsWith("All")) {
            bal = fnGetAllSproutBalance();
        } else {
            bal = rpc->getAllBalances()->value(addr);
        }

        auto balTxt = Settings::getZECUSDDisplayFormat(bal);

        if (bal < Turnstile::minMigrationAmount) {
            turnstile.fromBalance->setStyleSheet("color: red;");
            turnstile.fromBalance->setText(balTxt % " [You need at least "
                        % Settings::getZECDisplayFormat(Turnstile::minMigrationAmount)
                        % " for automatic migration]");
            turnstile.buttonBox->button(QDialogButtonBox::Ok)->setEnabled(false);
        } else {
            turnstile.fromBalance->setStyleSheet("");
            turnstile.buttonBox->button(QDialogButtonBox::Ok)->setEnabled(true);
            turnstile.fromBalance->setText(balTxt);
        }
    };

    if (!fromAddr.isEmpty())
        turnstile.migrateZaddList->setCurrentText(fromAddr);

    fnUpdateSproutBalance(turnstile.migrateZaddList->currentText());

    // Combo box selection event
    QObject::connect(turnstile.migrateZaddList, &QComboBox::currentTextChanged, fnUpdateSproutBalance);

    // Privacy level combobox
    // Num tx over num blocks
    QList<std::tuple<int, int>> privOptions;
    privOptions.push_back(std::make_tuple<int, int>(3, 576));
    privOptions.push_back(std::make_tuple<int, int>(5, 1152));
    privOptions.push_back(std::make_tuple<int, int>(10, 2304));

    QObject::connect(turnstile.privLevel, QOverload<int>::of(&QComboBox::currentIndexChanged), [=] (auto idx) {
        // Update the fees
        turnstile.minerFee->setText(
            Settings::getZECUSDDisplayFormat(std::get<0>(privOptions[idx]) * Settings::getMinerFee()));
    });

    for (auto i : privOptions) {
        turnstile.privLevel->addItem(QString::number((int)(std::get<1>(i) / 24 / 24)) % " days (" % // 24 blks/hr * 24 hrs per day
                                     QString::number(std::get<1>(i)) % " blocks, ~" %
                                     QString::number(std::get<0>(i)) % " txns)"
        );
    }

    turnstile.buttonBox->button(QDialogButtonBox::Ok)->setText("Start");

    if (d.exec() == QDialog::Accepted) {
        auto privLevel = privOptions[turnstile.privLevel->currentIndex()];
        rpc->getTurnstile()->planMigration(
            turnstile.migrateZaddList->currentText(),
            turnstile.migrateTo->currentText(),
            std::get<0>(privLevel), std::get<1>(privLevel));

        QMessageBox::information(this, "Backup your wallet.zero",
                                    "The migration will now start. You can check progress in the File -> Sapling Turnstile menu.\n\nYOU MUST BACKUP YOUR wallet.zero NOW!\n\nNew Addresses have been added to your wallet which will be used for the migration.",
                                    QMessageBox::Ok);
    }
}

/*
void MainWindow::setupTurnstileDialog() {
    // Turnstile migration
    QObject::connect(ui->actionTurnstile_Migration, &QAction::triggered, [=] () {
        // If the underlying zerod has support for the migration and there is no existing migration
        // in progress, use that.
        if (rpc->getMigrationStatus()->available && !rpc->getTurnstile()->isMigrationPresent()) {
            Turnstile::showZcashdMigration(this);
        } else {
            // Else, show the ZeroWallet turnstile tool

            // If there is current migration that is present, show the progress button
            if (rpc->getTurnstile()->isMigrationPresent())
                turnstileProgress();
            else
                turnstileDoMigration();
        }
    });

}
*/

void MainWindow::setupStatusBar() {
    // Status Bar
    loadingLabel = new QLabel();
    loadingMovie = new QMovie(":/icons/res/loading.gif");
    loadingMovie->setScaledSize(QSize(32, 16));
    loadingMovie->start();
    loadingLabel->setAttribute(Qt::WA_NoSystemBackground);
    loadingLabel->setMovie(loadingMovie);

    ui->statusBar->addPermanentWidget(loadingLabel);
    loadingLabel->setVisible(false);

    // Custom status bar menu
    ui->statusBar->setContextMenuPolicy(Qt::CustomContextMenu);
    QObject::connect(ui->statusBar, &QStatusBar::customContextMenuRequested, [=](QPoint pos) {
        auto msg = ui->statusBar->currentMessage();
        QMenu menu(this);

        if (!msg.isEmpty() && msg.startsWith(Settings::txidStatusMessage)) {
            auto txid = msg.split(":")[1].trimmed();
            menu.addAction(tr("Copy txid"), [=]() {
                QGuiApplication::clipboard()->setText(txid);
            });
            menu.addAction(tr("View tx on block explorer"), [=]() {
                Settings::openTxInExplorer(txid);
            });
        }

        menu.addAction(tr("Refresh"), [=]() {
            rpc->refresh(true);
        });
        QPoint gpos(mapToGlobal(pos).x(), mapToGlobal(pos).y() + this->height() - ui->statusBar->height());
        menu.exec(gpos);
    });

    statusLabel = new QLabel();
    ui->statusBar->addPermanentWidget(statusLabel);

    statusIcon = new QLabel();
    ui->statusBar->addPermanentWidget(statusIcon);
}

void MainWindow::setupSettingsModal() {
    // Set up File -> Settings action
    QObject::connect(ui->actionSettings, &QAction::triggered, [=]() {
        QDialog settingsDialog(this);
        Ui_Settings settings;
        settings.setupUi(&settingsDialog);
        Settings::saveRestore(&settingsDialog);

        // Setup theme combo
        int theme_index = settings.comboBoxTheme->findText(Settings::getInstance()->get_theme_name(), Qt::MatchExactly);
        settings.comboBoxTheme->setCurrentIndex(theme_index);

        QObject::connect(settings.comboBoxTheme, &QComboBox::currentTextChanged, [=] (QString theme_name) {
            this->slot_change_theme(theme_name);
        });

        // Custom fees
        settings.chkCustomFees->setChecked(Settings::getInstance()->getAllowCustomFees());

        // Auto shielding
        settings.chkAutoShield->setChecked(Settings::getInstance()->getAutoShield());

        // Check for updates
        settings.chkCheckUpdates->setChecked(Settings::getInstance()->getCheckForUpdates());

        // Fetch prices
        settings.chkFetchPrices->setChecked(Settings::getInstance()->getAllowFetchPrices());

        // Connection Settings
        QIntValidator validator(0, 65535);
        settings.port->setValidator(&validator);

        //Show where setting are coming from
        auto zcashConfLocation = Settings::getInstance()->getZcashdConfLocation();
        if (!zcashConfLocation.isEmpty()) {
            settings.confMsg->setText("Settings are being read from \n" + zcashConfLocation);
        } else {
            settings.confMsg->setText("No local zero.conf found. Please configure connection manually.");
        }

        // Load current values into the dialog from the connection
        bool isUsingTor = false;
        bool isUsingConsolidation = false;
        bool isUsingDeleteTx = false;
        QString consolidationtxfee = "0.0001";
        QList<QString> cAddresses;
        QString port;
        QString rpcuser;
        QString rpcpassword;

        if (rpc->getConnection() != nullptr) {
            auto conf = rpc->getConnection()->config;
            settings.hostname->setText(conf->host);
            settings.port->setText(conf->port);
            port = conf->port;
            settings.rpcuser->setText(conf->rpcuser);
            rpcuser = conf->rpcuser;
            settings.rpcpassword->setText(conf->rpcpassword);
            rpcpassword = conf->rpcpassword;


            //Use DeleteTx
            isUsingDeleteTx = (conf->deletetx == "1") ? true : false;
            settings.chkDeleteTx->setChecked(isUsingDeleteTx);
            consolidationtxfee = conf->consolidationtxfee;

            // Use Consolidation
            isUsingConsolidation = (conf->consolidation == "1") ? true : false;
            settings.chkConsolidation->setChecked(isUsingConsolidation);
            cAddresses = conf->consolidationAddresses;


            // Use Tor
            isUsingTor = conf->proxy.isEmpty() ? false : true;
            settings.chkTor->setChecked(isUsingTor);
        }

        //Set Tx Fee in Settings UI
        settings.consolidationFeeAmt->setValidator( new QDoubleValidator(0.0000, 0.0005, 8, this));
        QRegExp re("\\d*");  // a digit (\d), zero or more times (*)
        if (re.exactMatch(consolidationtxfee)){
            double ctxFee = consolidationtxfee.toDouble();
            settings.consolidationFeeAmt->setText(QString::number((ctxFee/1e8)));
        } else {
            settings.consolidationFeeAmt->setText(QString::number(0.0001));
        }

        //Setup Consolidation table for addresses
        ConsolodationAddressModel* consolodationAddressModel = new ConsolodationAddressModel(settings.consolidationAddressTable);
        settings.consolidationAddressTable->setModel(consolodationAddressModel);
        consolodationAddressModel->addConsolidationData(cAddresses);
        settings.consolidationAddressTable->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);

        //Setup Consolidation table CustomContextMenu - Delete button
        settings.consolidationAddressTable->setContextMenuPolicy(Qt::CustomContextMenu);
        QObject::connect(settings.consolidationAddressTable, &QTableView::customContextMenuRequested, [=] (QPoint pos) {
            QModelIndex index = settings.consolidationAddressTable->indexAt(pos);
            if (index.row() < 0) return;

            QMenu menu(this);

            auto addrModel = dynamic_cast<ConsolodationAddressModel *>(settings.consolidationAddressTable->model());
            QString addr = addrModel->getAddress(index.row());

            menu.addAction(tr("Delete Address"), [=] () {
                addrModel->deleteAddress(addr);
                ui->statusBar->showMessage(tr("Consolidation Address Removed."), 3 * 1000);
            });

            menu.exec(settings.consolidationAddressTable->viewport()->mapToGlobal(pos));
        });

        // Add Consolidation Address add button
        QObject::connect(settings.btnAddConsolidationAddress, &QPushButton::clicked, this, [=] () {
            auto addrModel = dynamic_cast<ConsolodationAddressModel *>(settings.consolidationAddressTable->model());
            auto addr = settings.newConsolidationAddress->text();
            addrModel->addAddress(addr);
        });


        if (!rpc->isEmbedded()) {
          QString tooltip = tr("You're using an external zerod. Please configure manually.");
          //Enable DeleteTx and Consolidation only if using embedded zerod
          settings.chkDeleteTx->setEnabled(false);
          settings.chkConsolidation->setEnabled(false);
          settings.consolidationFeeAmt->setEnabled(false);
          settings.consolidationAddressTable->setEnabled(false);
          settings.btnAddConsolidationAddress->setEnabled(false);
          settings.newConsolidationAddress->setEnabled(false);
          settings.chkDeleteTx->setToolTip(tooltip);
          settings.chkConsolidation->setToolTip(tooltip);
          settings.consolidationFeeAmt->setToolTip(tooltip);
          settings.consolidationAddressTable->setToolTip(tooltip);
          settings.btnAddConsolidationAddress->setToolTip(tooltip);
          settings.newConsolidationAddress->setToolTip(tooltip);

          //Enable Connection settings option only if using embedded zerod
          settings.hostname->setEnabled(false);
          settings.port->setEnabled(false);
          settings.rpcuser->setEnabled(false);
          settings.rpcpassword->setEnabled(false);
          settings.hostname->setToolTip(tooltip);
          settings.port->setToolTip(tooltip);
          settings.rpcuser->setToolTip(tooltip);
          settings.rpcpassword->setToolTip(tooltip);

          // Enable the troubleshooting options only if using embedded zerod
          settings.chkRescan->setEnabled(false);
          settings.chkReindex->setEnabled(false);
          settings.chkRescan->setToolTip(tooltip);
          settings.chkReindex->setToolTip(tooltip);

          //Enable Tor option only if using embedded zerod
          settings.chkTor->setEnabled(false);
          settings.lblTor->setEnabled(false);
          settings.chkTor->setToolTip(tooltip);
          settings.lblTor->setToolTip(tooltip);

        } else {
          settings.chkDeleteTx->setEnabled(true);
          settings.chkConsolidation->setEnabled(true);
          settings.consolidationFeeAmt->setEnabled(true);
          settings.consolidationAddressTable->setEnabled(true);
          settings.btnAddConsolidationAddress->setEnabled(true);
          settings.newConsolidationAddress->setEnabled(true);

          settings.hostname->setEnabled(false);
          settings.port->setEnabled(true);
          settings.rpcuser->setEnabled(true);
          settings.rpcpassword->setEnabled(true);

          settings.chkRescan->setEnabled(true);
          settings.chkReindex->setEnabled(true);

          settings.chkTor->setEnabled(true);
          settings.lblTor->setEnabled(true);
        }

        // Connection tab by default
        settings.tabWidget->setCurrentIndex(0);

        if (settingsDialog.exec() == QDialog::Accepted) {
            // Custom fees
            bool customFees = settings.chkCustomFees->isChecked();
            Settings::getInstance()->setAllowCustomFees(customFees);
            ui->minerFeeAmt->setReadOnly(!customFees);
            if (!customFees)
                ui->minerFeeAmt->setText(Settings::getDecimalString(Settings::getMinerFee()));

            // Auto shield
            Settings::getInstance()->setAutoShield(settings.chkAutoShield->isChecked());

            // Check for updates
            Settings::getInstance()->setCheckForUpdates(settings.chkCheckUpdates->isChecked());

            // Allow fetching prices
            Settings::getInstance()->setAllowFetchPrices(settings.chkFetchPrices->isChecked());

            // Check to see if state changed and wallet needs to restart
            bool showRestartInfo = false;
            bool forceRestart = false;

            //Update Connection Settings
            if (port != settings.port->text() || rpcuser != settings.rpcuser->text() || rpcpassword != settings.rpcpassword->text()) {
                Settings::removeFromZcashConf(zcashConfLocation, "rpcport");
                Settings::addToZcashConf(zcashConfLocation, "rpcport=" + settings.port->text());
                Settings::removeFromZcashConf(zcashConfLocation, "rpcuser");
                Settings::addToZcashConf(zcashConfLocation, "rpcuser=" + settings.rpcuser->text());
                Settings::removeFromZcashConf(zcashConfLocation, "rpcpassword");
                Settings::addToZcashConf(zcashConfLocation, "rpcpassword=" + settings.rpcpassword->text());

                showRestartInfo = true;
                forceRestart = true;
            }


            //Update Tor Settings
            if (!isUsingTor && settings.chkTor->isChecked()) {
                Settings::removeFromZcashConf(zcashConfLocation, "proxy");
                Settings::addToZcashConf(zcashConfLocation, "proxy=127.0.0.1:9050");
                rpc->getConnection()->config->proxy = "proxy=127.0.0.1:9050";
                showRestartInfo = true;
            }
            if (isUsingTor && !settings.chkTor->isChecked()) {
                Settings::removeFromZcashConf(zcashConfLocation, "proxy");
                rpc->getConnection()->config->proxy.clear();
                showRestartInfo = true;
            }

            //Update DeleteTx Settings
            if (!isUsingDeleteTx && settings.chkDeleteTx->isChecked()) {
                Settings::removeFromZcashConf(zcashConfLocation, "deletetx");
                Settings::removeFromZcashConf(zcashConfLocation, "keeptxfornblocks");
                Settings::removeFromZcashConf(zcashConfLocation, "keeptxnum");
                Settings::addToZcashConf(zcashConfLocation, "deletetx=1");
                Settings::addToZcashConf(zcashConfLocation, "keeptxfornblocks=1");
                Settings::addToZcashConf(zcashConfLocation, "keeptxnum=1");
                rpc->getConnection()->config->deletetx= "1";
                showRestartInfo = true;
            }
            if (isUsingDeleteTx && !settings.chkDeleteTx->isChecked()) {
                Settings::removeFromZcashConf(zcashConfLocation, "deletetx");
                Settings::removeFromZcashConf(zcashConfLocation, "keeptxfornblocks");
                Settings::removeFromZcashConf(zcashConfLocation, "keeptxnum");
                rpc->getConnection()->config->deletetx.clear();
                showRestartInfo = true;
            }

            //Update Consolidation Settings
            if (!isUsingConsolidation && settings.chkConsolidation->isChecked()) {
                QString cFee = QString::number(settings.consolidationFeeAmt->text().toDouble() * 1e8);
                Settings::removeFromZcashConf(zcashConfLocation, "consolidation");
                Settings::removeFromZcashConf(zcashConfLocation, "consolidationtxfee");
                Settings::addToZcashConf(zcashConfLocation, "consolidation=1");
                Settings::addToZcashConf(zcashConfLocation, "consolidationtxfee=" + cFee);
                rpc->getConnection()->config->consolidation = "1";
                showRestartInfo = true;
            }
            if (isUsingConsolidation && !settings.chkConsolidation->isChecked()) {
                Settings::removeFromZcashConf(zcashConfLocation, "consolidation");
                Settings::removeFromZcashConf(zcashConfLocation, "consolidationtxfee");
                rpc->getConnection()->config->consolidation .clear();
                showRestartInfo = true;
            }

            //Update troubleshooting options
            if (settings.chkRescan->isChecked()) {
                Settings::addToZcashConf(zcashConfLocation, "rescan=1");
                showRestartInfo = true;
            }

            if (settings.chkReindex->isChecked()) {
                Settings::addToZcashConf(zcashConfLocation, "reindex=1");
                showRestartInfo = true;
            }

            if (showRestartInfo) {
                QMessageBox restartMsg;
                restartMsg.setText("ZeroWallet needs to restart to update the wallet config.");
                restartMsg.setInformativeText("ZeroWallet will now close, please restart ZeroWallet to continue.");
                if (!forceRestart) {
                  restartMsg.setStandardButtons(QMessageBox::Ok | QMessageBox::Cancel);
                } else {
                  restartMsg.setStandardButtons(QMessageBox::Ok);
                }
                restartMsg.setDefaultButton(QMessageBox::Ok);

                QSpacerItem* horizontalSpacer = new QSpacerItem(500, 0, QSizePolicy::Minimum, QSizePolicy::Expanding);
                QGridLayout* layout = (QGridLayout*)restartMsg.layout();
                layout->addItem(horizontalSpacer, layout->rowCount(), 0, 1, layout->columnCount());

                int ret = restartMsg.exec();

                 if (ret == QMessageBox::Ok || forceRestart) {
                    QTimer::singleShot(1, [=]() { this->close(); });
                 }
            }
        }
    });
}

void MainWindow::addressBook() {
    // Check to see if there is a target.
    //QRegExp re("Address[0-9]+", Qt::CaseInsensitive);
    const QRegularExpression re("Address[0-9]+", QRegularExpression::CaseInsensitiveOption);
    for (auto target: ui->sendToWidgets->findChildren<QLineEdit *>(re)) {
        if (target->hasFocus()) {
            AddressBook::open(this, target);
            return;
        }
    };

    // If there was no target, then just run with no target.
    AddressBook::open(this);
}

void MainWindow::discord() {
    QString url = "https://discordapp.com/invite/Jq5knn5";
    QDesktopServices::openUrl(QUrl(url));
}

void MainWindow::website() {
    QString url = "https://zerocurrency.io";
    QDesktopServices::openUrl(QUrl(url));
}

// void MainWindow::safenodes() {
//     QString url = "https://safenodes.org/";
//     QDesktopServices::openUrl(QUrl(url));
// }

void MainWindow::donate() {
    // Set up a donation to me :)
    clearSendForm();

    ui->Address1->setText(Settings::getDonationAddr());
    ui->Address1->setCursorPosition(0);
    ui->Amount1->setText("0.00");
    ui->MemoTxt1->setText(tr("Some feedback about ZeroWallet or Zero...!"));

    ui->statusBar->showMessage(tr("Send OleksandrBlack feedback about ") % Settings::getTokenName() % tr(" or ZeroWallet"));

    // And switch to the send tab.
    ui->tabWidget->setCurrentIndex(1);
}

/**
 * Validate an address
 */
void MainWindow::validateAddress() {
    // Make sure everything is up and running
    if (!getRPC() || !getRPC()->getConnection())
        return;

    // First thing is ask the user for an address
    bool ok;
    auto address = QInputDialog::getText(this, tr("Enter Address to validate"),
        tr("Transparent or Shielded Address:") + QString(" ").repeated(140),    // Pad the label so the dialog box is wide enough
        QLineEdit::Normal, "", &ok);
    if (!ok)
        return;

    getRPC()->validateAddress(address, [=] (json props) {
        QDialog d(this);
        Ui_ValidateAddress va;
        va.setupUi(&d);
        Settings::saveRestore(&d);
        Settings::saveRestoreTableHeader(va.tblProps, &d, "validateaddressprops");
        va.tblProps->horizontalHeader()->setStretchLastSection(true);

        va.lblAddress->setText(address);

        QList<QPair<QString, QString>> propsList;
        for (auto it = props.begin(); it != props.end(); it++) {

            propsList.append(
                QPair<QString, QString>(
                    QString::fromStdString(it.key()), QString::fromStdString(it.value().dump()))
            );
        }

        ValidateAddressesModel model(va.tblProps, propsList);
        va.tblProps->setModel(&model);

        d.exec();
    });

}

void MainWindow::postToZBoard() {
    QDialog d(this);
    Ui_zboard zb;
    zb.setupUi(&d);
    Settings::saveRestore(&d);

    if (rpc->getConnection() == nullptr)
        return;

    // Fill the from field with sapling addresses.
    for (auto i = rpc->getAllBalances()->keyBegin(); i != rpc->getAllBalances()->keyEnd(); i++) {
        if (Settings::getInstance()->isSaplingAddress(*i) && rpc->getAllBalances()->value(*i) > 0) {
            zb.fromAddr->addItem(*i);
        }
    }

    QMap<QString, QString> topics;
    // Insert the main topic automatically
    topics.insert("#Main_Area", Settings::getInstance()->isTestnet() ? Settings::getDonationAddr() : Settings::getZboardAddr());
    zb.topicsList->addItem(topics.firstKey());
    // Then call the API to get topics, and if it returns successfully, then add the rest of the topics
    rpc->getZboardTopics([&](QMap<QString, QString> topicsMap) {
        for (auto t : topicsMap.keys()) {
            topics.insert(t, Settings::getInstance()->isTestnet() ? Settings::getDonationAddr() : topicsMap[t]);
            zb.topicsList->addItem(t);
        }
    });

    // Testnet warning
    if (Settings::getInstance()->isTestnet()) {
        zb.testnetWarning->setText(tr("You are on testnet, your post won't actually appear on z-board.net"));
    }
    else {
        zb.testnetWarning->setText("");
    }

    QRegExpValidator v(QRegExp("^[a-zA-Z0-9_]{3,20}$"), zb.postAs);
    zb.postAs->setValidator(&v);

    zb.feeAmount->setText(Settings::getZECUSDDisplayFormat(Settings::getZboardAmount() + Settings::getMinerFee()));

    auto fnBuildNameMemo = [=]() -> QString {
        auto memo = zb.memoTxt->toPlainText().trimmed();
        if (!zb.postAs->text().trimmed().isEmpty())
            memo = zb.postAs->text().trimmed() + ":: " + memo;
        return memo;
    };

    auto fnUpdateMemoSize = [=]() {
        QString txt = fnBuildNameMemo();
        zb.memoSize->setText(QString::number(txt.toUtf8().size()) + "/512");

        if (txt.toUtf8().size() <= 512) {
            // Everything is fine
            zb.buttonBox->button(QDialogButtonBox::Ok)->setEnabled(true);
            zb.memoSize->setStyleSheet("");
        }
        else {
            // Overweight
            zb.buttonBox->button(QDialogButtonBox::Ok)->setEnabled(false);
            zb.memoSize->setStyleSheet("color: red;");
        }

        // Disallow blank memos
        if (zb.memoTxt->toPlainText().trimmed().isEmpty()) {
            zb.buttonBox->button(QDialogButtonBox::Ok)->setEnabled(false);
        }
        else {
            zb.buttonBox->button(QDialogButtonBox::Ok)->setEnabled(true);
        }
    };

    // Memo text changed
    QObject::connect(zb.memoTxt, &QPlainTextEdit::textChanged, fnUpdateMemoSize);
    QObject::connect(zb.postAs, &QLineEdit::textChanged, fnUpdateMemoSize);

    zb.memoTxt->setFocus();
    fnUpdateMemoSize();

    if (d.exec() == QDialog::Accepted) {
        // Create a transaction.
        Tx tx;

        // Send from your first sapling address that has a balance.
        tx.fromAddr = zb.fromAddr->currentText();
        if (tx.fromAddr.isEmpty()) {
            QMessageBox::critical(this, "Error Posting Message", tr("You need a sapling address with available balance to post"), QMessageBox::Ok);
            return;
        }

        auto memo = zb.memoTxt->toPlainText().trimmed();
        if (!zb.postAs->text().trimmed().isEmpty())
            memo = zb.postAs->text().trimmed() + ":: " + memo;

        auto toAddr = topics[zb.topicsList->currentText()];
        tx.toAddrs.push_back(ToFields{ toAddr, Settings::getZboardAmount(), memo, memo.toUtf8().toHex() });
        tx.fee = Settings::getMinerFee();

        // And send the Tx
        rpc->executeStandardUITransaction(tx);
    }
}

void MainWindow::doImport(QList<QString>* keys) {
    if (rpc->getConnection() == nullptr) {
        // No connection, just return
        return;
    }

    if (keys->isEmpty()) {
        delete keys;
        ui->statusBar->showMessage(tr("Private key import rescan finished"));
        return;
    }

    // Pop the first key
    QString key = keys->first();
    keys->pop_front();
    bool rescan = keys->isEmpty();

    if (key.startsWith("SK") ||
        key.startsWith("secret")) { // Z key
        rpc->importZPrivKey(key, rescan, [=] (auto) { this->doImport(keys); });
    } else {
        rpc->importTPrivKey(key, rescan, [=] (auto) { this->doImport(keys); });
    }
}


// Callback invoked when the RPC has finished loading all the balances, and the UI
// is now ready to send transactions.
void MainWindow::balancesReady() {
    // First-time check
    if (uiPaymentsReady)
        return;

    uiPaymentsReady = true;
    qDebug() << "Payment UI now ready!";

    // There is a pending URI payment (from the command line, or from a secondary instance),
    // process it.
    if (!pendingURIPayment.isEmpty()) {
        qDebug() << "Paying Zero URI";
        payZcashURI(pendingURIPayment);
        pendingURIPayment = "";
    }

    // Execute any pending Recurring payments
    Recurring::getInstance()->processPending(this);
}

// Event filter for MacOS specific handling of payment URIs
bool MainWindow::eventFilter(QObject *object, QEvent *event) {
    if (event->type() == QEvent::FileOpen) {
        QFileOpenEvent *fileEvent = static_cast<QFileOpenEvent*>(event);
        if (!fileEvent->url().isEmpty())
            payZcashURI(fileEvent->url().toString());

        return true;
    }

    return QObject::eventFilter(object, event);
}


// Pay the Zero URI by showing a confirmation window. If the URI parameter is empty, the UI
// will prompt for one. If the myAddr is empty, then the default from address is used to send
// the transaction.
void MainWindow::payZcashURI(QString uri, QString myAddr) {
    // If the Payments UI is not ready (i.e, all balances have not loaded), defer the payment URI
    if (!isPaymentsReady()) {
        qDebug() << "Payment UI not ready, waiting for UI to pay URI";
        pendingURIPayment = uri;
        return;
    }

    // If there was no URI passed, ask the user for one.
    if (uri.isEmpty()) {
        uri = QInputDialog::getText(this, tr("Paste Zero URI"),
            "Zero URI" + QString(" ").repeated(180));
    }

    // If there's no URI, just exit
    if (uri.isEmpty())
        return;

    // Extract the address
    qDebug() << "Received URI " << uri;
    PaymentURI paymentInfo = Settings::parseURI(uri);
    if (!paymentInfo.error.isEmpty()) {
        QMessageBox::critical(this, tr("Error paying zero URI"),
                tr("URI should be of the form 'zero:<addr>?amt=x&memo=y") + "\n" + paymentInfo.error);
        return;
    }

    // Now, set the fields on the send tab
    clearSendForm();

    if (!myAddr.isEmpty()) {
        ui->inputsCombo->setCurrentText(myAddr);
    }

    ui->Address1->setText(paymentInfo.addr);
    ui->Address1->setCursorPosition(0);
    ui->Amount1->setText(Settings::getDecimalString(paymentInfo.amt.toDouble()));
    ui->MemoTxt1->setText(paymentInfo.memo);

    // And switch to the send tab.
    ui->tabWidget->setCurrentIndex(1);
    raise();

    // And click the send button if the amount is > 0, to validate everything. If everything is OK, it will show the confirm box
    // else, show the error message;
    if (paymentInfo.amt > 0) {
        sendButton();
    }
}


void MainWindow::importPrivKey() {
    QDialog d(this);
    Ui_PrivKey pui;
    pui.setupUi(&d);
    Settings::saveRestore(&d);

    pui.buttonBox->button(QDialogButtonBox::Save)->setVisible(false);
    pui.helpLbl->setText(QString() %
                        tr("Please paste your private keys (z-Addr or t-Addr) here, one per line") % ".\n" %
                        tr("The keys will be imported into your connected zerod node"));

    if (d.exec() == QDialog::Accepted && !pui.privKeyTxt->toPlainText().trimmed().isEmpty()) {
        auto rawkeys = pui.privKeyTxt->toPlainText().trimmed().split("\n");

        QList<QString> keysTmp;
        // Filter out all the empty keys.
        std::copy_if(rawkeys.begin(), rawkeys.end(), std::back_inserter(keysTmp), [=] (auto key) {
            return !key.startsWith("#") && !key.trimmed().isEmpty();
        });

        auto keys = new QList<QString>();
        std::transform(keysTmp.begin(), keysTmp.end(), std::back_inserter(*keys), [=](auto key) {
            return key.trimmed().split(" ")[0];
        });

        // Special case.
        // Sometimes, when importing from a paperwallet or such, the key is split by newlines, and might have
        // been pasted like that. So check to see if the whole thing is one big private key
        if (Settings::getInstance()->isValidSaplingPrivateKey(keys->join(""))) {
            auto multiline = keys;
            keys = new QList<QString>();
            keys->append(multiline->join(""));
            delete multiline;
        }

        // Start the import. The function takes ownership of keys
        QTimer::singleShot(1, [=]() {doImport(keys);});

        // Show the dialog that keys will be imported.
        QMessageBox::information(this,
            "Imported", tr("The keys were imported. It may take several minutes to rescan the blockchain. Until then, functionality may be limited"),
            QMessageBox::Ok);
    }
}

/**
 * Export transaction history into a CSV file
 */
void MainWindow::exportTransactions() {
    // First, get the export file name
    QString exportName = "zero-transactions-" + QDateTime::currentDateTime().toString("yyyyMMdd") + ".csv";

    QUrl csvName = QFileDialog::getSaveFileUrl(this,
            tr("Export transactions"), exportName, "CSV file (*.csv)");

    if (csvName.isEmpty())
        return;

    if (!rpc->getTransactionsModel()->exportToCsv(csvName.toLocalFile())) {
        QMessageBox::critical(this, tr("Error"),
            tr("Error exporting transactions, file was not saved"), QMessageBox::Ok);
    }
}

/**
 * Backup the wallet.zero file. This is kind of a hack, since it has to read from the filesystem rather than an RPC call
 * This might fail for various reasons - Remote zerod, non-standard locations, custom params passed to zerod, many others
*/
void MainWindow::backupWalletDat() {
    if (!rpc->getConnection())
        return;

    QDir zcashdir(rpc->getConnection()->config->zcashDir);
    QString backupDefaultName = "zero-wallet-backup-" + QDateTime::currentDateTime().toString("yyyyMMdd") + ".zero";

    if (Settings::getInstance()->isTestnet()) {
        zcashdir.cd("testnet3");
        backupDefaultName = "testnet-" + backupDefaultName;
    }

    QFile wallet(zcashdir.filePath("wallet.zero"));
    if (!wallet.exists()) {
        QMessageBox::critical(this, tr("No wallet.zero"), tr("Couldn't find the wallet.zero on this computer") + "\n" +
            tr("You need to back it up from the machine zerod is running on"), QMessageBox::Ok);
        return;
    }

    QUrl backupName = QFileDialog::getSaveFileUrl(this, tr("Backup wallet.zero"), backupDefaultName, "Data file (*.zero)");
    if (backupName.isEmpty())
        return;

    if (!wallet.copy(backupName.toLocalFile())) {
        QMessageBox::critical(this, tr("Couldn't backup"), tr("Couldn't backup the wallet.zero file.") +
            tr("You need to back it up manually."), QMessageBox::Ok);
    }
}

void MainWindow::exportAllKeys() {
    exportKeys("");
}

void MainWindow::exportKeys(QString addr) {
    bool allKeys = addr.isEmpty() ? true : false;

    QDialog d(this);
    Ui_PrivKey pui;
    pui.setupUi(&d);

    // Make the window big by default
    auto ps = this->geometry();
    QMargins margin = QMargins() + 50;
    d.setGeometry(ps.marginsRemoved(margin));

    Settings::saveRestore(&d);

    pui.privKeyTxt->setPlainText(tr("This might take several minutes. Loading..."));
    pui.privKeyTxt->setReadOnly(true);
    pui.privKeyTxt->setLineWrapMode(QPlainTextEdit::LineWrapMode::NoWrap);

    if (allKeys)
        pui.helpLbl->setText(tr("These are all the private keys for all the addresses in your wallet"));
    else
        pui.helpLbl->setText(tr("Private key for ") + addr);

    // Disable the save button until it finishes loading
    pui.buttonBox->button(QDialogButtonBox::Save)->setEnabled(false);
    pui.buttonBox->button(QDialogButtonBox::Ok)->setVisible(false);

    // Wire up save button
    QObject::connect(pui.buttonBox->button(QDialogButtonBox::Save), &QPushButton::clicked, [=] () {
        QString fileName = QFileDialog::getSaveFileName(this, tr("Save File"),
                           allKeys ? "zero-all-privatekeys.txt" : "zero-privatekey.txt");
        QFile file(fileName);
        if (!file.open(QIODevice::WriteOnly)) {
            QMessageBox::information(this, tr("Unable to open file"), file.errorString());
            return;
        }
        QTextStream out(&file);
        out << pui.privKeyTxt->toPlainText();
    });

    // Call the API
    auto isDialogAlive = std::make_shared<bool>(true);

    auto fnUpdateUIWithKeys = [=](QList<QPair<QString, QString>> privKeys) {
        // Check to see if we are still showing.
        if (! *(isDialogAlive.get()) ) return;

        QString allKeysTxt;
        for (auto keypair : privKeys) {
            allKeysTxt = allKeysTxt % keypair.second % " # addr=" % keypair.first % "\n";
        }

        pui.privKeyTxt->setPlainText(allKeysTxt);
        pui.buttonBox->button(QDialogButtonBox::Save)->setEnabled(true);
    };

    if (allKeys) {
        rpc->getAllPrivKeys(fnUpdateUIWithKeys);
    }
    else {
        auto fnAddKey = [=](json key) {
            QList<QPair<QString, QString>> singleAddrKey;
            singleAddrKey.push_back(QPair<QString, QString>(addr, QString::fromStdString(key.get<json::string_t>())));
            fnUpdateUIWithKeys(singleAddrKey);
        };

        if (Settings::getInstance()->isZAddress(addr)) {
            rpc->getZPrivKey(addr, fnAddKey);
        }
        else {
            rpc->getTPrivKey(addr, fnAddKey);
        }
    }

    d.exec();
    *isDialogAlive = false;
}

void MainWindow::setupBalancesTab() {
    ui->unconfirmedWarning->setVisible(false);
    ui->lblSyncWarning->setVisible(false);
    ui->lblSyncWarningReceive->setVisible(false);

    // Double click on balances table
    auto fnDoSendFrom = [=](const QString& addr, const QString& to = QString(), bool sendMax = false) {
        // Find the inputs combo
        for (int i = 0; i < ui->inputsCombo->count(); i++) {
            auto inputComboAddress = ui->inputsCombo->itemText(i);
            if (inputComboAddress.startsWith(addr)) {
                ui->inputsCombo->setCurrentIndex(i);
                break;
            }
        }

        // If there's a to address, add that as well
        if (!to.isEmpty()) {
            // Remember to clear any existing address fields, because we are creating a new transaction.
            this->clearSendForm();
            ui->Address1->setText(to);
        }

        // See if max button has to be checked
        if (sendMax) {
            ui->Max1->setChecked(true);
        }

        // And switch to the send tab.
        ui->tabWidget->setCurrentIndex(2);
    };

    // Double click opens up memo if one exists
    QObject::connect(ui->balancesOverviewTable, &QTableView::doubleClicked, [=](auto index) {
        index = index.sibling(index.row(), 0);
        auto addr = AddressBook::addressFromAddressLabel(ui->balancesOverviewTable->model()->data(index).toString());

        fnDoSendFrom(addr);
    });

    // Double click opens up memo if one exists
    QObject::connect(ui->balancesTable, &QTableView::doubleClicked, [=](auto index) {
        index = index.sibling(index.row(), 0);
        auto addr = AddressBook::addressFromAddressLabel(ui->balancesTable->model()->data(index).toString());

        fnDoSendFrom(addr);
    });

    // Setup context menu on balances tab
    ui->balancesOverviewTable->setContextMenuPolicy(Qt::CustomContextMenu);
    QObject::connect(ui->balancesOverviewTable, &QTableView::customContextMenuRequested, [=] (QPoint pos) {
        QModelIndex index = ui->balancesOverviewTable->indexAt(pos);
        if (index.row() < 0) return;

        index = index.sibling(index.row(), 0);
        auto addr = AddressBook::addressFromAddressLabel(
                            ui->balancesOverviewTable->model()->data(index).toString());

        QMenu menu(this);

        menu.addAction(tr("Copy address"), [=] () {
            QClipboard *clipboard = QGuiApplication::clipboard();
            clipboard->setText(addr);
            ui->statusBar->showMessage(tr("Copied to clipboard"), 3 * 1000);
        });

        menu.addAction(tr("Get private key"), [=] () {
            this->exportKeys(addr);
        });

        menu.addAction("Send from " % addr.left(40) % (addr.size() > 40 ? "..." : ""), [=]() {
            fnDoSendFrom(addr);
        });

        if (Settings::isTAddress(addr)) {
            auto defaultSapling = rpc->getDefaultSaplingAddress();
            if (!defaultSapling.isEmpty()) {
                menu.addAction(tr("Shield balance to Sapling"), [=] () {
                    fnDoSendFrom(addr, defaultSapling, true);
                });
            }

            menu.addAction(tr("View on block explorer"), [=] () {
                Settings::openAddressInExplorer(addr);
            });
        }

        if (Settings::getInstance()->isSproutAddress(addr)) {
            menu.addAction(tr("Migrate to Sapling"), [=] () {
                this->turnstileDoMigration(addr);
            });
        }

        menu.exec(ui->balancesOverviewTable->viewport()->mapToGlobal(pos));
    });

    // Setup context menu on balances tab
    ui->balancesTable->setContextMenuPolicy(Qt::CustomContextMenu);
    QObject::connect(ui->balancesTable, &QTableView::customContextMenuRequested, [=] (QPoint pos) {
        QModelIndex index = ui->balancesTable->indexAt(pos);
        if (index.row() < 0) return;

        index = index.sibling(index.row(), 0);
        auto addr = AddressBook::addressFromAddressLabel(
                            ui->balancesTable->model()->data(index).toString());

        QMenu menu(this);

        menu.addAction(tr("Copy address"), [=] () {
            QClipboard *clipboard = QGuiApplication::clipboard();
            clipboard->setText(addr);
            ui->statusBar->showMessage(tr("Copied to clipboard"), 3 * 1000);
        });

        menu.addAction(tr("Get private key"), [=] () {
            this->exportKeys(addr);
        });

        menu.addAction("Send from " % addr.left(40) % (addr.size() > 40 ? "..." : ""), [=]() {
            fnDoSendFrom(addr);
        });

        if (Settings::isTAddress(addr)) {
            auto defaultSapling = rpc->getDefaultSaplingAddress();
            if (!defaultSapling.isEmpty()) {
                menu.addAction(tr("Shield balance to Sapling"), [=] () {
                    fnDoSendFrom(addr, defaultSapling, true);
                });
            }

            menu.addAction(tr("View on block explorer"), [=] () {
                Settings::openAddressInExplorer(addr);
            });
        }

        if (Settings::getInstance()->isSproutAddress(addr)) {
            menu.addAction(tr("Migrate to Sapling"), [=] () {
                this->turnstileDoMigration(addr);
            });
        }

        menu.exec(ui->balancesTable->viewport()->mapToGlobal(pos));
    });
}

void MainWindow::setupZcashdTab() {
    ui->zerologo->setPixmap(QPixmap(":/img/res/zerodlogo.gif").scaled(256, 256, Qt::KeepAspectRatio, Qt::SmoothTransformation));
}

//void MainWindow::SafeNodesTab() {
//    ui->safenodelogo->setPixmap(QPixmap(":/img/res/zero.png").scaled(128, 128, Qt::KeepAspectRatio, Qt::SmoothTransformation));
//}

void MainWindow::setupTransactionsTab() {
    // Double click opens up memo if one exists
    QObject::connect(ui->transactionsTable, &QTableView::doubleClicked, [=] (auto index) {
        auto txModel = dynamic_cast<TxTableModel *>(ui->transactionsTable->model());
        QString memo = txModel->getMemo(index.row());

        if (!memo.isEmpty()) {
            QMessageBox mb(QMessageBox::Information, tr("Memo"), memo, QMessageBox::Ok, this);
            mb.setTextInteractionFlags(Qt::TextSelectableByMouse | Qt::TextSelectableByKeyboard);
            mb.exec();
        }
    });

    // Set up context menu on transactions tab
    ui->transactionsTable->setContextMenuPolicy(Qt::CustomContextMenu);

    // Table right click
    QObject::connect(ui->transactionsTable, &QTableView::customContextMenuRequested, [=] (QPoint pos) {
        QModelIndex index = ui->transactionsTable->indexAt(pos);
        if (index.row() < 0) return;

        QMenu menu(this);

        auto txModel = dynamic_cast<TxTableModel *>(ui->transactionsTable->model());

        QString txid = txModel->getTxId(index.row());
        QString memo = txModel->getMemo(index.row());
        QString addr = txModel->getAddr(index.row());

        menu.addAction(tr("Copy txid"), [=] () {
            QGuiApplication::clipboard()->setText(txid);
            ui->statusBar->showMessage(tr("Copied to clipboard"), 3 * 1000);
        });

        if (!addr.isEmpty()) {
            menu.addAction(tr("Copy address"), [=] () {
                QGuiApplication::clipboard()->setText(addr);
                ui->statusBar->showMessage(tr("Copied to clipboard"), 3 * 1000);
            });
        }

        menu.addAction(tr("View on block explorer"), [=] () {
            Settings::openTxInExplorer(txid);
        });

        // Payment Request
        if (!memo.isEmpty() && memo.startsWith("zero:")) {
            menu.addAction(tr("View Payment Request"), [=] () {
                RequestDialog::showPaymentConfirmation(this, memo);
            });
        }

        // View Memo
        if (!memo.isEmpty()) {
            menu.addAction(tr("View Memo"), [=] () {
                QMessageBox mb(QMessageBox::Information, tr("Memo"), memo, QMessageBox::Ok, this);
                mb.setTextInteractionFlags(Qt::TextSelectableByMouse | Qt::TextSelectableByKeyboard);
                mb.exec();
            });
        }

        // If memo contains a reply to address, add a "Reply to" menu item
        if (!memo.isEmpty()) {
            int lastPost     = memo.trimmed().lastIndexOf(QRegExp("[\r\n]+"));
            QString lastWord = memo.right(memo.length() - lastPost - 1);

            if (Settings::getInstance()->isSaplingAddress(lastWord) ||
                Settings::getInstance()->isSproutAddress(lastWord)) {
                menu.addAction(tr("Reply to ") + lastWord.left(25) + "...", [=]() {
                    // First, cancel any pending stuff in the send tab by pretending to click
                    // the cancel button
                    cancelButton();

                    // Then set up the fields in the send tab
                    ui->Address1->setText(lastWord);
                    ui->Address1->setCursorPosition(0);
                    ui->Amount1->setText("0.0001");

                    // And switch to the send tab.
                    ui->tabWidget->setCurrentIndex(1);

                    qApp->processEvents();

                    // Click the memo button
                    this->memoButtonClicked(1, true);
                });
            }
        }

        menu.exec(ui->transactionsTable->viewport()->mapToGlobal(pos));
    });
}

void MainWindow::setupZNodesTab() {


    //auto lznModel = rpc->localZeroNodesTableModel;
    // Double click opens up memo if one exists
//    QObject::connect(ui->tableZeroNodeGlobal, &QTableView::doubleClicked, [=] (auto index) {
//        auto gznModel = dynamic_cast<GlobalZNTableModel *>(ui->tableZeroNodeGlobal->model());
//        qint64 rank = gznModel->getGZNRank(index.row());
//    });

    int row = -1;
    ui->tableZeroNodeLocal->setContextMenuPolicy(Qt::CustomContextMenu);
    QObject::connect(ui->tableZeroNodeLocal, &QTableView::customContextMenuRequested, [=] (QPoint pos) mutable {
        auto lznModel = dynamic_cast<LocalZNTableModel *>(ui->tableZeroNodeLocal->model());

        QModelIndex index = ui->tableZeroNodeLocal->indexAt(pos);
        if (index.row() < 0) return;

        row = index.row();

        LocalZeroNodes lineNode {
            ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 0)).toString(),
            ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 1)).toString(),
            ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 2)).toString(),
            ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 3)).toString(),
            ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 4)).toString(),
            ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 5)).toLongLong()
        };

        QMenu menu(this);
        menu.addAction(tr("Start"), [=]() {
          rpc->startZNAlias(lineNode.alias);
        });

        if (lineNode.alias.startsWith("#")) {
            menu.addAction(tr("Enable"), [=] () {
                LocalZeroNodes updatedNode {
                  "RESTART",
                  lineNode.alias.right(lineNode.alias.length() - 1),
                  lineNode.ipAddress,
                  lineNode.privateKey,
                  lineNode.txid,
                  lineNode.index
                };
                // updatedNode.status = QString::fromStdString("RESTART");
                // updatedNode.alias = lineNode.alias.replace("#","")
                lznModel->updateZeroNodeSetup(lineNode, updatedNode);
            });
        } else {
            menu.addAction(tr("Disable"), [=]() {
                LocalZeroNodes updatedNode {
                  "RESTART",
                  QString::fromStdString("#") + lineNode.alias,
                  lineNode.ipAddress,
                  lineNode.privateKey,
                  lineNode.txid,
                  lineNode.index
                };
                // updatedNode.status = QString::fromStdString("RESTART");
                // updatedNode.alias = QString::fromStdString("#") + lineNode.alias;
                lznModel->updateZeroNodeSetup(lineNode, updatedNode);
            });
        }


        menu.addAction(tr("Edit"), [=]() {
          auto lznModel = dynamic_cast<LocalZNTableModel *>(ui->tableZeroNodeLocal->model());
          Ui_znsetup znSetup;
          QDialog dialog(this);
          znSetup.setupUi(&dialog);
          lznModel->setupZeroNode(this, &znSetup, &dialog, lineNode);
          dialog.exec();
        });

        menu.addAction(tr("Delete"), [=]() {
          lznModel->deleteZeroNodeFromSetup(lineNode);
        });

        menu.exec(ui->tableZeroNodeLocal->viewport()->mapToGlobal(pos));
    });



    QObject::connect(ui->btnZNRefresh, &QPushButton::clicked, [=] () {
        rpc->refreshGZeroNodes();
    });

    QObject::connect(ui->btnZNNew, &QPushButton::clicked, [=] () {
        auto lznModel = dynamic_cast<LocalZNTableModel *>(ui->tableZeroNodeLocal->model());
        Ui_znsetup znSetup;
        QDialog dialog(this);
        znSetup.setupUi(&dialog);
        const LocalZeroNodes newNode {"","","","","",0};
        lznModel->setupZeroNode(this, &znSetup, &dialog, newNode);
        dialog.exec();
    });

    QObject::connect(ui->btnZNStart, &QPushButton::clicked, [=] () {

        QPoint pos;
        QModelIndex index = ui->tableZeroNodeLocal->indexAt(pos);
        if (index.row() < 0) return;

        rpc->startZNAlias(ui->tableZeroNodeLocal->model()->data(index.sibling(index.row(), 1)).toString());

    });

    QObject::connect(ui->btnZNStartAll, &QPushButton::clicked, [=] () {
        rpc->startZNAll();
    });

//    QObject::connect(ui->btnZNClearCache, &QPushButton::clicked, [=] () {
//    });
}

void MainWindow::addNewZaddr() {
    rpc->newZaddr([=] (json reply) {
        QString addr = QString::fromStdString(reply.get<json::string_t>());
        // Make sure the RPC class reloads the z-addrs for future use
        rpc->refreshAddresses();

        // Just double make sure the z-address is still checked
        if (ui->rdioZSAddr->isChecked() ) {
            ui->listReceiveAddresses->insertItem(0, addr);
            ui->listReceiveAddresses->setCurrentIndex(0);

            ui->statusBar->showMessage(QString::fromStdString("Created new zAddr") %
                                       ("(Sapling)"),
                                       10 * 1000);
        }
    });
}


// Adds sapling or sprout z-addresses to the combo box. Technically, returns a
// lambda, which can be connected to the appropriate signal
std::function<void(bool)> MainWindow::addZAddrsToComboList() {
    return [=] (bool checked) {
        if (checked && this->rpc->getAllZAddresses() != nullptr) {
            auto addrs = this->rpc->getAllZAddresses();

            // Save the current address, so we can update it later
            auto zaddr = ui->listReceiveAddresses->currentText();
            ui->listReceiveAddresses->clear();

            std::for_each(addrs->begin(), addrs->end(), [=] (auto addr) {
                if ( (Settings::getInstance()->isSaplingAddress(addr)) ||
                    (!Settings::getInstance()->isSaplingAddress(addr))) {
                        if (rpc->getAllBalances()) {
                            auto bal = rpc->getAllBalances()->value(addr);
                            ui->listReceiveAddresses->addItem(addr, bal);
                        }
                }
            });

            if (!zaddr.isEmpty() && Settings::isZAddress(zaddr)) {
                ui->listReceiveAddresses->setCurrentText(zaddr);
            }

            // If z-addrs are empty, then create a new one.
            if (addrs->isEmpty()) {
                addNewZaddr();
            }
        }
    };
}

void MainWindow::setupReceiveTab() {
    auto addNewTAddr = [=] () {
        rpc->newTaddr([=] (json reply) {
            QString addr = QString::fromStdString(reply.get<json::string_t>());
            // Make sure the RPC class reloads the t-addrs for future use
            rpc->refreshAddresses();

            // Just double make sure the t-address is still checked
            if (ui->rdioTAddr->isChecked()) {
                ui->listReceiveAddresses->insertItem(0, addr);
                ui->listReceiveAddresses->setCurrentIndex(0);

                ui->statusBar->showMessage(tr("Created new t-Addr"), 10 * 1000);
            }
        });
    };

    // Connect t-addr radio button
    QObject::connect(ui->rdioTAddr, &QRadioButton::toggled, [=] (bool checked) {
        // Whenever the t-address is selected, we generate a new address, because we don't
        // want to reuse t-addrs
        if (checked && this->rpc->getUTXOs() != nullptr) {
            updateTAddrCombo(checked);
        }

        // Toggle the "View all addresses" button as well
        ui->btnViewAllAddresses->setVisible(checked);
    });

    // View all addresses goes to "View all private keys"
    QObject::connect(ui->btnViewAllAddresses, &QPushButton::clicked, [=] () {
        // If there's no RPC, return
        if (!getRPC())
            return;

        QDialog d(this);
        Ui_ViewAddressesDialog viewaddrs;
        viewaddrs.setupUi(&d);
        Settings::saveRestore(&d);
        Settings::saveRestoreTableHeader(viewaddrs.tblAddresses, &d, "viewalladdressestable");
        viewaddrs.tblAddresses->horizontalHeader()->setStretchLastSection(true);

        ViewAllAddressesModel model(viewaddrs.tblAddresses, *getRPC()->getAllTAddresses(), getRPC());
        viewaddrs.tblAddresses->setModel(&model);

        QObject::connect(viewaddrs.btnExportAll, &QPushButton::clicked,  this, &MainWindow::exportAllKeys);

        viewaddrs.tblAddresses->setContextMenuPolicy(Qt::CustomContextMenu);
        QObject::connect(viewaddrs.tblAddresses, &QTableView::customContextMenuRequested, [=] (QPoint pos) {
            QModelIndex index = viewaddrs.tblAddresses->indexAt(pos);
            if (index.row() < 0) return;

            index = index.sibling(index.row(), 0);
            QString addr = viewaddrs.tblAddresses->model()->data(index).toString();

            QMenu menu(this);
            menu.addAction(tr("Export Private Key"), [=] () {
                if (addr.isEmpty())
                    return;

                this->exportKeys(addr);
            });
            menu.addAction(tr("Copy Address"), [=]() {
                QGuiApplication::clipboard()->setText(addr);
            });
            menu.exec(viewaddrs.tblAddresses->viewport()->mapToGlobal(pos));
        });

        d.exec();
    });

    QObject::connect(ui->rdioZSAddr, &QRadioButton::toggled, addZAddrsToComboList());

    // Explicitly get new address button.
    QObject::connect(ui->btnReceiveNewAddr, &QPushButton::clicked, [=] () {
        if (!rpc->getConnection())
            return;

        if (ui->rdioZSAddr->isChecked()) {
            addNewZaddr();
        } else if (ui->rdioTAddr->isChecked()) {
            addNewTAddr();
        }
    });

    // Focus enter for the Receive Tab
    QObject::connect(ui->tabWidget, &QTabWidget::currentChanged, [=] (int tab) {
        if (tab == 2) {
            // Switched to receive tab, select the z-addr radio button
            ui->rdioZSAddr->setChecked(true);
            ui->btnViewAllAddresses->setVisible(false);

            // And then select the first one
            ui->listReceiveAddresses->setCurrentIndex(0);
        }
    });

    // Validator for label
    QRegExpValidator* v = new QRegExpValidator(QRegExp(Settings::labelRegExp), ui->rcvLabel);
    ui->rcvLabel->setValidator(v);

    // Select item in address list
    QObject::connect(ui->listReceiveAddresses,
        QOverload<int>::of(&QComboBox::currentIndexChanged), [=] (int index) {
        QString addr = ui->listReceiveAddresses->itemText(index);
        if (addr.isEmpty()) {
            // Draw empty stuff

            ui->rcvLabel->clear();
            ui->rcvBal->clear();
            ui->txtReceive->clear();
            ui->qrcodeDisplay->clear();
            return;
        }

        auto label = AddressBook::getInstance()->getLabelForAddress(addr);
        if (label.isEmpty()) {
            ui->rcvUpdateLabel->setText("Add Label");
        }
        else {
            ui->rcvUpdateLabel->setText("Update Label");
        }

        ui->rcvLabel->setText(label);
        ui->rcvBal->setText(Settings::getZECUSDDisplayFormat(rpc->getAllBalances()->value(addr)));
        ui->txtReceive->setPlainText(addr);
        ui->qrcodeDisplay->setQrcodeString(addr);
        if (rpc->getUsedAddresses()->value(addr, false)) {
            ui->rcvBal->setToolTip(tr("Address has been previously used"));
        } else {
            ui->rcvBal->setToolTip(tr("Address is unused"));
        }

    });

    // Receive tab add/update label
    QObject::connect(ui->rcvUpdateLabel, &QPushButton::clicked, [=]() {
        QString addr = ui->listReceiveAddresses->currentText();
        if (addr.isEmpty())
            return;

        auto curLabel = AddressBook::getInstance()->getLabelForAddress(addr);
        auto label = ui->rcvLabel->text().trimmed();

        if (curLabel == label)  // Nothing to update
            return;

        QString info;

        if (!curLabel.isEmpty() && label.isEmpty()) {
            info = "Removed Label '" % curLabel % "'";
            AddressBook::getInstance()->removeAddressLabel(curLabel, addr);
        }
        else if (!curLabel.isEmpty() && !label.isEmpty()) {
            info = "Updated Label '" % curLabel % "' to '" % label % "'";
            AddressBook::getInstance()->updateLabel(curLabel, addr, label);
        }
        else if (curLabel.isEmpty() && !label.isEmpty()) {
            info = "Added Label '" % label % "'";
            AddressBook::getInstance()->addAddressLabel(label, addr);
        }

        // Update labels everywhere on the UI
        updateLabels();

        // Show the user feedback
        if (!info.isEmpty()) {
            QMessageBox::information(this, "Label", info, QMessageBox::Ok);
        }
    });

    // Receive Export Key
    QObject::connect(ui->exportKey, &QPushButton::clicked, [=]() {
        QString addr = ui->listReceiveAddresses->currentText();
        if (addr.isEmpty())
            return;

        this->exportKeys(addr);
    });
}

void MainWindow::updateTAddrCombo(bool checked) {
    if (checked) {
        auto utxos = this->rpc->getUTXOs();

        // Save the current address so we can restore it later
        auto currentTaddr = ui->listReceiveAddresses->currentText();

        ui->listReceiveAddresses->clear();

        // Maintain a set of addresses so we don't duplicate any, because we'll be adding
        // t addresses multiple times
        QSet<QString> addrs;

        // 1. Add all t addresses that have a balance
        std::for_each(utxos->begin(), utxos->end(), [=, &addrs](auto& utxo) {
            auto addr = utxo.address;
            if (Settings::isTAddress(addr) && !addrs.contains(addr)) {
                auto bal = rpc->getAllBalances()->value(addr);
                ui->listReceiveAddresses->addItem(addr, bal);

                addrs.insert(addr);
            }
        });

        // 2. Add all t addresses that have a label
        auto allTaddrs = this->rpc->getAllTAddresses();
        QSet<QString> labels;
        for (auto p : AddressBook::getInstance()->getAllAddressLabels()) {
            labels.insert(p.second);
        }
        std::for_each(allTaddrs->begin(), allTaddrs->end(), [=, &addrs] (auto& taddr) {
            // If the address is in the address book, add it.
            if (labels.contains(taddr) && !addrs.contains(taddr)) {
                addrs.insert(taddr);
                ui->listReceiveAddresses->addItem(taddr, 0);
            }
        });

        // 3. Add all t-addresses. We won't add more than 20 total t-addresses,
        // since it will overwhelm the dropdown
        for (int i=0; addrs.size() < 20 && i < allTaddrs->size(); i++) {
            auto addr = allTaddrs->at(i);
            if (!addrs.contains(addr))  {
                addrs.insert(addr);
                // Balance is zero since it has not been previously added
                ui->listReceiveAddresses->addItem(addr, 0);
            }
        }

        // 4. Add the previously selected t-address
        if (!currentTaddr.isEmpty() && Settings::isTAddress(currentTaddr)) {
            // Make sure the current taddr is in the list
            if (!addrs.contains(currentTaddr)) {
                auto bal = rpc->getAllBalances()->value(currentTaddr);
                ui->listReceiveAddresses->addItem(currentTaddr, bal);
            }
            ui->listReceiveAddresses->setCurrentText(currentTaddr);
        }

        // 5. Add a last, disabled item if there are remaining items
        if (allTaddrs->size() > addrs.size()) {
            auto num = QString::number(allTaddrs->size() - addrs.size());
            ui->listReceiveAddresses->addItem("-- " + num + " more --", 0);

            QStandardItemModel* model = qobject_cast<QStandardItemModel*>(ui->listReceiveAddresses->model());
            QStandardItem* item =  model->findItems("--", Qt::MatchStartsWith)[0];
            item->setFlags(item->flags() & ~Qt::ItemIsEnabled);
        }
    }
};

// Updates the labels everywhere on the UI. Call this after the labels have been updated
void MainWindow::updateLabels() {
    // Update the Receive tab
    if (ui->rdioTAddr->isChecked()) {
        updateTAddrCombo(true);
    }
    else {
        addZAddrsToComboList();
    }

    // Update the Send Tab
    updateFromCombo();

    // Update the autocomplete
    updateLabelsAutoComplete();
}

void MainWindow::slot_change_theme(const QString& theme_name)
{
    Settings::getInstance()->set_theme_name(theme_name);

    // Include css
    QString saved_theme_name;
    try
    {
       saved_theme_name = Settings::getInstance()->get_theme_name();
    }
    catch (...)
    {
        saved_theme_name = "default";
    }

    QFile qFile(":/css/res/css/" + saved_theme_name +".css");
    if (qFile.open(QFile::ReadOnly))
    {
      QString styleSheet = QLatin1String(qFile.readAll());
      this->setStyleSheet(""); // try to reset styles
      this->setStyleSheet(styleSheet);
    }

}

MainWindow::~MainWindow()
{
    delete ui;
    delete rpc;
    delete labelCompleter;

    delete sendTxRecurringInfo;
    delete amtValidator;
    delete feesValidator;

    delete loadingMovie;
    delete logger;

    delete wsserver;
    delete wormhole;
}
