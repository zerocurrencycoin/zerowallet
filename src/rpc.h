#ifndef RPCCLIENT_H
#define RPCCLIENT_H

#include "precompiled.h"

#include "balancestablemodel.h"
#include "txtablemodel.h"
#include "globalzntablemodel.h"
#include "localzntablemodel.h"
#include "ui_mainwindow.h"
#include "ui_znsetup.h"
#include "mainwindow.h"
#include "connection.h"

using json = nlohmann::json;

class Turnstile;

struct GlobalZeroNodes{
    qint64          rank;
    QString         address;
    qint64          version;
    QString         status;
    qint64          active;
    QString          lastSeen;
    QString          lastPaid;
    QString         txid;
    QString         ipAddress;
    bool            local;
};

struct TransactionItem {
    QString         type;
    qint64          datetime;
    QString         address;
    QString         txid;
    double          amount;
    long            confirmations;
    QString         fromAddr;
    QString         memo;
};

struct WatchedTx {
    QString opid;
    Tx tx;
    std::function<void(QString, QString)> completed;
    std::function<void(QString, QString)> error;
};

struct MigrationStatus {
    bool            available;     // Whether the underlying zcashd supports migration?
    bool            enabled;
    QString         saplingAddress;
    double          unmigrated;
    double          migrated;
    QList<QString>  txids;
};

QString convertSecondsToDays(qint64 n);

class RPC
{
public:
    RPC(MainWindow* main);
    ~RPC();

    void setConnection(Connection* c);
    void setEZcashd(QProcess* p);
    const QProcess* getEZcashD() { return ezcashd; }

    void refresh(bool force = false);

    void refreshGZeroNodes();
    void startZNAlias(QString alias);
    void startZNAll();
    void getZNPrivateKey(Ui_znsetup* zn);
    void getZNOutputs(Ui_znsetup* zn, QList<ZNOutputs>* outputs, QList<LocalZeroNodes>* znData);
    void refreshAddresses();

    void checkForUpdate(bool silent = true);
    void refreshZECPrice();
    void getZboardTopics(std::function<void(QMap<QString, QString>)> cb);

    void executeStandardUITransaction(Tx tx);

    void executeTransaction(Tx tx,
        const std::function<void(QString opid)> submitted,
        const std::function<void(QString opid, QString txid)> computed,
        const std::function<void(QString opid, QString errStr)> error);

    void fillTxJsonParams(json& params, Tx tx);
    void sendZTransaction(json params, const std::function<void(json)>& cb, const std::function<void(QString)>& err);
    void watchTxStatus();

    const QMap<QString, WatchedTx> getWatchingTxns() { return watchingOps; }
    void addNewTxToWatch(const QString& newOpid, WatchedTx wtx);

    const LocalZNTableModel*          getLocalZeroNodesModel()  { return localZeroNodesTableModel; }
    const GlobalZNTableModel*         getGlobalZeroNodesModel() { return globalZeroNodesTableModel; }
    const TxTableModel*               getTransactionsModel()    { return transactionsTableModel; }
    const QList<QString>*             getAllZAddresses()        { return zaddresses; }
    const QList<QString>*             getAllTAddresses()        { return taddresses; }
    const QList<UnspentOutput>*       getUTXOs()                { return utxos; }
    const QMap<QString, double>*      getAllBalances()          { return balancesOverview; }
    const QMap<QString, bool>*        getUsedAddresses()        { return usedAddresses; }

    void newZaddr(const std::function<void(json)>& cb);
    void newTaddr(const std::function<void(json)>& cb);

    void getZPrivKey(QString addr, const std::function<void(json)>& cb);
    void getTPrivKey(QString addr, const std::function<void(json)>& cb);
    void importZPrivKey(QString addr, bool rescan, const std::function<void(json)>& cb);
    void importTPrivKey(QString addr, bool rescan, const std::function<void(json)>& cb);
    void validateAddress(QString address, const std::function<void(json)>& cb);

    void shutdownZcashd();
    void noConnection();
    bool isEmbedded() { return ezcashd != nullptr; }

    QString getDefaultSaplingAddress();
    QString getDefaultTAddress();

    void getAllPrivKeys(const std::function<void(QList<QPair<QString, QString>>)>);

    Turnstile*  getTurnstile()  { return turnstile; }
    Connection* getConnection() { return conn; }

    const MigrationStatus*      getMigrationStatus() { return &migrationStatus; }
    void                        setMigrationStatus(bool enabled);

private:
    void refreshGetAllData();
    void refreshMigration();

    bool processUnspent     (const json& reply, QMap<QString, double>* newBalances, QList<UnspentOutput>* newUtxos);
    void updateUI           (bool anyUnconfirmed);

    void getInfoThenRefresh(bool force);

    void getBalance(const std::function<void(json)>& cb);

    void getTransparentUnspent  (const std::function<void(json)>& cb);
    void getZUnspent            (const std::function<void(json)>& cb);
    void getTransactions        (const std::function<void(json)>& cb);
    void getZAddresses          (const std::function<void(json)>& cb);
    void getTAddresses          (const std::function<void(json)>& cb);
    void startZeroNodeAll       (const std::function<void(json)>& cb);
    void startZeroNodeAlias     (QString alias, const std::function<void(json)>& cb);
    void getCreateZeroNodeKey   (const std::function<void(json)>& cb);
    void getZeroNodeOutputs     (const std::function<void(json)>& cb);
    void getGZeroNodeList       (const std::function<void(json)>& cb);
    void getAllData             (const std::function<void(json)>& cb);

    Connection*                 conn                        = nullptr;
    QProcess*                   ezcashd                     = nullptr;

    QList<UnspentOutput>*       utxos                       = nullptr;
    QMap<QString, double>*      balancesOverview            = nullptr;
    QList<allBalances>*         addressBalances             = nullptr;
    QMap<QString, bool>*        usedAddresses               = nullptr;
    QList<QString>*             zaddresses                  = nullptr;
    QList<QString>*             taddresses                  = nullptr;

    QMap<QString, WatchedTx>    watchingOps;

    GlobalZNTableModel*             globalZeroNodesTableModel   = nullptr;
    LocalZNTableModel*              localZeroNodesTableModel    = nullptr;
    TxTableModel*                   transactionsTableModel      = nullptr;
    BalancesOverviewTableModel*     balancesOverviewTableModel  = nullptr;
    BalancesTableModel*             balancesTableModel          = nullptr;

    QTimer*                     timer;
    QTimer*                     txTimer;
    QTimer*                     priceTimer;

    Ui::MainWindow*             ui;
    MainWindow*                 main;
    Turnstile*                  turnstile;

    // Sapling turnstile migration status (for the zcashd v2.0.5 tool)
    MigrationStatus             migrationStatus;

    // Current balance in the UI. If this number updates, then refresh the UI
    QString                     currentBalance;
};

#endif // RPCCLIENT_H
