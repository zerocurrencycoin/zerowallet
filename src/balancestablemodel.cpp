#include "balancestablemodel.h"
#include "addressbook.h"
#include "settings.h"


BalancesOverviewTableModel::BalancesOverviewTableModel(QObject *parent)
    : QAbstractTableModel(parent) {
}

void BalancesOverviewTableModel::setNewData(const QMap<QString, double>* balances,
    const QList<UnspentOutput>* outputs)
{
    loading = false;

    int currentRows = rowCount(QModelIndex());
    // Copy over the utxos for our use
    delete utxos;
    utxos = new QList<UnspentOutput>();
    // This is a QList deep copy.
    *utxos = *outputs;

    // Process the address balances into a list
    delete modeldata;
    modeldata = new QList<std::tuple<QString, double>>();
    std::for_each(balances->keyBegin(), balances->keyEnd(), [=] (auto keyIt) {
        if (balances->value(keyIt) > 0)
            modeldata->push_back(std::make_tuple(keyIt, balances->value(keyIt)));
    });

    // And then update the data
    dataChanged(index(0, 0), index(modeldata->size()-1, columnCount(index(0,0))-1));

    // Change the layout only if the number of rows changed
    if (modeldata && modeldata->size() != currentRows)
        layoutChanged();
}

BalancesOverviewTableModel::~BalancesOverviewTableModel() {
    delete modeldata;
    delete utxos;
}

int BalancesOverviewTableModel::rowCount(const QModelIndex&) const
{
    if (modeldata == nullptr) {
        if (loading)
            return 1;
        else
            return 0;
    }
    return modeldata->size();
}

int BalancesOverviewTableModel::columnCount(const QModelIndex&) const
{
    return 2;
}

QVariant BalancesOverviewTableModel::data(const QModelIndex &index, int role) const
{
    if (loading) {
        if (role == Qt::DisplayRole)
            return "Loading...";
        else
            return QVariant();
    }

    if (role == Qt::TextAlignmentRole && index.column() == 1) return QVariant(Qt::AlignRight | Qt::AlignVCenter);

    if (role == Qt::ForegroundRole) {
        // If any of the UTXOs for this address has zero confirmations, paint it in red
        const auto& addr = std::get<0>(modeldata->at(index.row()));
        for (auto utxo : *utxos) {
            if (utxo.address == addr && utxo.confirmations == 0) {
                QBrush b;
                b.setColor(Qt::red);
                return b;
            }
        }

        // Else, just return the default brush
        QBrush b;
        b.setColor(Qt::black);
        return b;
    }

    if (role == Qt::DisplayRole) {
        switch (index.column()) {
        case 0: return AddressBook::addLabelToAddress(std::get<0>(modeldata->at(index.row())));
        case 1: return Settings::getZECDisplayFormat(std::get<1>(modeldata->at(index.row())));
        }
    }

    if(role == Qt::ToolTipRole) {
        switch (index.column()) {
        case 0: return AddressBook::addLabelToAddress(std::get<0>(modeldata->at(index.row())));
        case 1: return Settings::getUSDFromZecAmount(std::get<1>(modeldata->at(index.row())));
        }
    }

    return QVariant();
}


QVariant BalancesOverviewTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (role == Qt::TextAlignmentRole && section == 1) {
        return QVariant(Qt::AlignRight | Qt::AlignVCenter);
    }

    if (role == Qt::FontRole) {
        QFont f;
        f.setBold(true);
        return f;
    }

    if (role != Qt::DisplayRole)
        return QVariant();

    if (orientation == Qt::Horizontal) {
        switch (section) {
        case 0:                 return tr("Address");
        case 1:                 return tr("Amount");
        default:                return QVariant();
        }
    }
    return QVariant();
}








BalancesTableModel::BalancesTableModel(QObject *parent)
    : QAbstractTableModel(parent) {
}

void BalancesTableModel::setNewData(const QList<allBalances>* balances) {
    loading = false;
    // Process the address balances into a list
    delete modeldata;
    modeldata = new QList<allBalances>();

    if (balances != nullptr) std::copy( balances->begin(),  balances->end(), std::back_inserter(*modeldata));

    // And then update the data
    dataChanged(index(0, 0), index(modeldata->size()-1, columnCount(index(0,0))-1));
    layoutChanged();
}

BalancesTableModel::~BalancesTableModel() {
    delete modeldata;
}

int BalancesTableModel::rowCount(const QModelIndex&) const
{
    if (modeldata == nullptr) {
        if (loading)
            return 1;
        else
            return 0;
    }
    return modeldata->size();
}

int BalancesTableModel::columnCount(const QModelIndex&) const
{
    return 6;
}

QVariant BalancesTableModel::data(const QModelIndex &index, int role) const
{
    if (loading) {
        if (role == Qt::DisplayRole)
            return "Loading...";
        else
            return QVariant();
    }

    if (role == Qt::TextAlignmentRole) {
        switch (index.column()) {
            case 0: return QVariant(Qt::AlignLeft | Qt::AlignVCenter);
            case 1: return QVariant(Qt::AlignCenter | Qt::AlignVCenter);
            case 2: return QVariant(Qt::AlignRight | Qt::AlignVCenter);
            case 3: return QVariant(Qt::AlignRight | Qt::AlignVCenter);
            case 4: return QVariant(Qt::AlignRight | Qt::AlignVCenter);
            case 5: return QVariant(Qt::AlignRight | Qt::AlignVCenter);
        }
    }

    if (role == Qt::ForegroundRole) {
        QBrush b;
        b.setColor(Qt::black);
        return b;
    }

    if (role == Qt::DisplayRole) {
        switch (index.column()) {
            case 0: return AddressBook::addLabelToAddress((modeldata->at(index.row()).address));
            case 1: return modeldata->at(index.row()).watch == 0 ? "True" : "False";
            case 2: return QString::number(modeldata->at(index.row()).confirmed.toDouble(),'f', 8);
            case 3: return QString::number(modeldata->at(index.row()).unconfirmed.toDouble(),'f', 8);
            case 4: return QString::number(modeldata->at(index.row()).immature.toDouble(),'f', 8);
            case 5: return QString::number(modeldata->at(index.row()).locked.toDouble(),'f', 8);
        }
    }

    if(role == Qt::ToolTipRole) {
        switch (index.column()) {
            case 0: return AddressBook::addLabelToAddress((modeldata->at(index.row()).address));
            case 1: return modeldata->at(index.row()).watch == 0 ? "True" : "False";
            case 2: return QString::number(modeldata->at(index.row()).confirmed.toDouble(),'f', 8);
            case 3: return QString::number(modeldata->at(index.row()).unconfirmed.toDouble(),'f', 8);
            case 4: return QString::number(modeldata->at(index.row()).immature.toDouble(),'f', 8);
            case 5: return QString::number(modeldata->at(index.row()).locked.toDouble(),'f', 8);

        }
    }

    return QVariant();
}


QVariant BalancesTableModel::headerData(int section, Qt::Orientation orientation, int role) const
{

    if (role == Qt::TextAlignmentRole) {
        switch (section) {
            case 0: return QVariant(Qt::AlignLeft | Qt::AlignVCenter);
            case 1: return QVariant(Qt::AlignCenter | Qt::AlignVCenter);
            case 2: return QVariant(Qt::AlignCenter | Qt::AlignVCenter);
            case 3: return QVariant(Qt::AlignCenter | Qt::AlignVCenter);
            case 4: return QVariant(Qt::AlignCenter | Qt::AlignVCenter);
            case 5: return QVariant(Qt::AlignCenter | Qt::AlignVCenter);
        }
    }


    if (role == Qt::FontRole) {
        QFont f;
        f.setBold(true);
        return f;
    }

    if (role != Qt::DisplayRole)
        return QVariant();

    if (orientation == Qt::Horizontal) {
        switch (section) {
        case 0:                 return tr("Address");
        case 1:                 return tr("Watch");
        case 2:                 return tr("Confirmed");
        case 3:                 return tr("Unconfirmed");
        case 4:                 return tr("Immature");
        case 5:                 return tr("Locked");
        default:                return QVariant();
        }
    }
    return QVariant();
}
