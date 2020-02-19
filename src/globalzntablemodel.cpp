#include "globalzntablemodel.h"
#include "settings.h"
#include "rpc.h"

GlobalZNTableModel::GlobalZNTableModel(QObject *parent)
     : QAbstractTableModel(parent) {
    headers << QObject::tr("Rank") << QObject::tr("Address") << QObject::tr("Version")
            << QObject::tr("Status") << QObject::tr("Active") << QObject::tr("Last Seen")
            << QObject::tr("Last Paid") << QObject::tr("Txid") << QObject::tr("IP Address");
}

GlobalZNTableModel::~GlobalZNTableModel() {
    delete modeldata;
    delete znData;
}

void GlobalZNTableModel::addGlobalZNData(const QList<GlobalZeroNodes>& data) {
    delete znData;
    znData = new QList<GlobalZeroNodes>();
    std::copy(data.begin(), data.end(), std::back_inserter(*znData));

    updateAllZNData();
}

// bool TxTableModel::exportToCsv(QString fileName) const {
//     if (!modeldata)
//         return false;
//
//     QFile file(fileName);
//     if (!file.open(QIODevice::ReadWrite | QIODevice::Truncate))
//         return false;
//
//     QTextStream out(&file);   // we will serialize the data into the file
//
//     // Write headers
//     for (int i = 0; i < headers.length(); i++) {
//         out << "\"" << headers[i] << "\",";
//     }
//     out << "\"Memo\"";
//     out << endl;
//
//     // Write out each row
//     for (int row = 0; row < modeldata->length(); row++) {
//         for (int col = 0; col < headers.length(); col++) {
//             out << "\"" << data(index(row, col), Qt::DisplayRole).toString() << "\",";
//         }
//         // Memo
//         out << "\"" << modeldata->at(row).memo << "\"";
//         out << endl;
//     }
//
//     file.close();
//     return true;
// }

void GlobalZNTableModel::updateAllZNData() {
    auto newmodeldata = new QList<GlobalZeroNodes>();

    if (znData != nullptr) std::copy(znData->begin(), znData->end(), std::back_inserter(*newmodeldata));

    // Sort by reverse time
    std::sort(newmodeldata->begin(), newmodeldata->end(), [=] (auto a, auto b) {
        return a.rank < b.rank; // reverse sort
    });

    // And then swap out the modeldata with the new one.
    delete modeldata;
    modeldata = newmodeldata;

    dataChanged(index(0, 0), index(modeldata->size()-1, columnCount(index(0,0))-1));
    layoutChanged();
}

 int GlobalZNTableModel::rowCount(const QModelIndex&) const
 {
    if (modeldata == nullptr) return 0;
    return modeldata->size();
 }

 int GlobalZNTableModel::columnCount(const QModelIndex&) const
 {
    return headers.size();
 }


 QVariant GlobalZNTableModel::data(const QModelIndex &index, int role) const
 {
     // Align column 4,5 (confirmations, amount) right
    if (role == Qt::TextAlignmentRole)
        return QVariant(Qt::AlignVCenter);

    auto dat = modeldata->at(index.row());
    if (role == Qt::ForegroundRole) {
        // if (dat.confirmations <= 0) {
        //     QBrush b;
        //     b.setColor(Qt::red);
        //     return b;
        // }

        // Else, just return the default brush
        QBrush b;
        b.setColor(Qt::black);
        return b;
    }

    if (role == Qt::DisplayRole) {
        switch (index.column()) {
        case 0: return dat.rank;
        case 1: return dat.address;
        case 2: return dat.version;
        case 3: return dat.status;
        case 4: return convertSecondsToDays(dat.active);
        case 5: return dat.lastSeen;
        case 6: return dat.lastPaid;
        case 7: return dat.txid;
        case 8: return dat.ipAddress;
        }
    }

    // if (role == Qt::ToolTipRole) {
    //     switch (index.column()) {
    //     case 0: {
    //                 if (dat.memo.startsWith("zcash:")) {
    //                     return Settings::paymentURIPretty(Settings::parseURI(dat.memo));
    //                 } else {
    //                     return modeldata->at(index.row()).type +
    //                     (dat.memo.isEmpty() ? "" : " tx memo: \"" + dat.memo + "\"");
    //                 }
    //             }
    //     case 1: {
    //                 auto addr = modeldata->at(index.row()).address;
    //                 if (addr.trimmed().isEmpty())
    //                     return "(Shielded)";
    //                 else
    //                     return addr;
    //             }
    //     case 2: return QDateTime::fromMSecsSinceEpoch(modeldata->at(index.row()).datetime * (qint64)1000).toLocalTime().toString();
    //     case 3: return QString("%1 Network Confirmations").arg(QString::number(dat.confirmations));
    //     case 4: return Settings::getInstance()->getUSDFromZecAmount(modeldata->at(index.row()).amount);
    //     }
    // }

    // if (role == Qt::DecorationRole && index.column() == 0) {
    //     if (!dat.memo.isEmpty()) {
    //         // If the memo is a Payment URI, then show a payment request icon
    //         if (dat.memo.startsWith("zcash:")) {
    //             QIcon icon(":/icons/res/paymentreq.gif");
    //             return QVariant(icon.pixmap(16, 16));
    //         } else {
    //             // Return the info pixmap to indicate memo
    //             QIcon icon = QApplication::style()->standardIcon(QStyle::SP_MessageBoxInformation);
    //             return QVariant(icon.pixmap(16, 16));
    //             }
    //     } else {
    //         // Empty pixmap to make it align
    //         QPixmap p(16, 16);
    //         p.fill(Qt::white);
    //         return QVariant(p);
    //     }
    // }

    return QVariant();
 }


 QVariant GlobalZNTableModel::headerData(int section, Qt::Orientation orientation, int role) const
 {
     if (role == Qt::TextAlignmentRole)
        return QVariant(Qt::AlignCenter);

     if (role == Qt::FontRole) {
         QFont f;
         f.setBold(true);
         return f;
     }

     if (role == Qt::DisplayRole && orientation == Qt::Horizontal) {
         return headers.at(section);
     }

     return QVariant();
 }

qint64 GlobalZNTableModel::getGZNRank(int row) const {
    return modeldata->at(row).rank;
}

QString GlobalZNTableModel::getGZNAddr(int row) const {
    return modeldata->at(row).address;
}

qint64 GlobalZNTableModel::getGZNVersion(int row) const {
    return modeldata->at(row).version;
}

QString GlobalZNTableModel::getGZNStatus(int row) const {
    return modeldata->at(row).status;
}

qint64 GlobalZNTableModel::getGZNActive(int row) const {
    return modeldata->at(row).active;
}

qint64 GlobalZNTableModel::getGZNLastSeen(int row) const {
    return modeldata->at(row).lastSeen;
}

qint64 GlobalZNTableModel::getGZNLastPain(int row) const {
    return modeldata->at(row).lastPaid;
}

QString GlobalZNTableModel::getGZNTxid(int row) const {
    return modeldata->at(row).txid;
}

QString GlobalZNTableModel::getGZNIp(int row) const {
    return modeldata->at(row).ipAddress;
}
