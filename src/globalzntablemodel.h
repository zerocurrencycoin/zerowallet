#ifndef GLOBALZNTABLEMODEL_H
#define GLOBALZNTABLEMODEL_H

#include "precompiled.h"

struct GlobalZeroNodes;

class GlobalZNTableModel: public QAbstractTableModel
{
public:
    GlobalZNTableModel(QObject* parent);
    ~GlobalZNTableModel();

    void addGlobalZNData    (const QList<GlobalZeroNodes>& data);

    qint64   getGZNRank(int row) const;
    QString  getGZNAddr(int row) const;
    qint64   getGZNVersion(int row) const;
    QString  getGZNStatus(int row) const;
    qint64   getGZNActive(int row) const;
    qint64   getGZNLastSeen(int row) const;
    qint64   getGZNLastPain(int row) const;
    QString  getGZNTxid(int row) const;
    QString  getGZNIp(int row) const;

    int      rowCount(const QModelIndex &parent) const;
    int      columnCount(const QModelIndex &parent) const;
    QVariant data(const QModelIndex &index, int role) const;
    QVariant headerData(int section, Qt::Orientation orientation, int role) const;

private:
    void updateAllZNData();

    QList<GlobalZeroNodes>*   znData        = nullptr;

    QList<GlobalZeroNodes>*   modeldata     = nullptr;

    QList<QString>            headers;
};


#endif // GLOBALZNTABLEMODEL_H
