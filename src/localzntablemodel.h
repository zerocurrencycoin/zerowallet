#ifndef LOCALZNTABLEMODEL_H
#define LOCALZNTABLEMODEL_H

#include "precompiled.h"

struct LocalZeroNodes {
    QString         status;
    QString         alias;
    QString         ipAddress;
    QString         privateKey;
    QString         txid;
    qint64          index;
};

extern QList<LocalZeroNodes> zeroNodeSettings;

class LocalZNTableModel: public QAbstractTableModel
{
public:
    LocalZNTableModel(QObject* parent);
    ~LocalZNTableModel();

    void addLocalZNData();

    QString  getLZNStatus(int row) const;
    QString  getLZNAlias(int row) const;
    QString  getLZNIpAddress(int row) const;
    QString  getLZNPrivateKey(int row) const;
    QString  getLZNTxid(int row) const;
    qint64   getLZNIndex(int row) const;

    int      rowCount(const QModelIndex &parent) const;
    int      columnCount(const QModelIndex &parent) const;
    QVariant data(const QModelIndex &index, int role) const;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const;

private:
    void updateAllLZNData();

    QList<LocalZeroNodes>*    znData        = nullptr;

    QList<LocalZeroNodes>*    modeldata     = nullptr;

    QList<QString>            headers;
};


#endif // LOCALZNTABLEMODEL_H
