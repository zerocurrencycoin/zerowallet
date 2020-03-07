#include "localzntablemodel.h"
//#include "globalzntablemodel.h"
#include "settings.h"
#include "mainwindow.h"
#include "rpc.h"



QList<LocalZeroNodes> zeroNodeSettings;

LocalZNTableModel::LocalZNTableModel(QObject *parent)
     : QAbstractTableModel(parent) {
    headers << QObject::tr("Status") << QObject::tr("Alias") << QObject::tr("IP Address")
            << QObject::tr("Private Key") << QObject::tr("Txid") << QObject::tr("Index");
}

LocalZNTableModel::~LocalZNTableModel() {
    delete modeldata;
    delete znData;
    delete outputs;
}

void LocalZNTableModel::addLocalZNData() {
    delete znData;
    znData = new QList<LocalZeroNodes>();
    std::copy(zeroNodeSettings.begin(), zeroNodeSettings.end(), std::back_inserter(*znData));

    updateAllLZNData();
}

void LocalZNTableModel::setupZeroNode(MainWindow* main, Ui_znsetup* zn, QDialog* d, const LocalZeroNodes &lineNode) {

    int portIndex = lineNode.ipAddress.lastIndexOf(":");
    zn->txtZNAlias->setText(lineNode.alias);
    zn->txtZNIpAddress->setText(lineNode.ipAddress.left(portIndex));
    zn->txtZNPort->setText(QString::number(23801));
    zn->txtZNPrivateKey->setText(lineNode.privateKey);
    zn->txtZNOutput->setText(lineNode.txid);
    if (lineNode.txid.length() > 0) {
        zn->txtZNIndex->setText(QString::number(lineNode.index));
    } else {
        zn->txtZNIndex->setText(QString::number(0));
    }

    QObject::connect(zn->btnZNNewPrivKey, &QPushButton::clicked, [=] () {
        main->getRPC()->getZNPrivateKey(zn);
    });

    QObject::connect(zn->btnZNGetOutput, &QPushButton::clicked, [=] () {

        if (outputs == nullptr)
            outputs = new QList<ZNOutputs>;

        if (znData == nullptr)
            znData = new QList<LocalZeroNodes>;

        main->getRPC()->getZNOutputs(zn, outputs, znData);

    });

    QObject::connect(zn->btnZNUpdate, &QPushButton::clicked, [=] () {
        bool ok = false;
        qint64 index = zn->txtZNIndex->text().QString::toLongLong(&ok);

        if (zn->txtZNAlias->text().length() > 0 &&
            zn->txtZNIpAddress->text().length() > 0 &&
            zn->txtZNPort->text().length() > 0 &&
            zn->txtZNPrivateKey->text().length() > 0 &&
            zn->txtZNOutput->text().length() > 0 &&
            ok) {

            LocalZeroNodes newNode{
              "RESTART",
              zn->txtZNAlias->text(),
              zn->txtZNIpAddress->text() + ":" + zn->txtZNPort->text(),
              zn->txtZNPrivateKey->text(),
              zn->txtZNOutput->text(),
              index
            };

            if (lineNode.alias.length() == 0) {
                zeroNodeSettings.push_back(newNode);
                addLocalZNData();
                writeZeroNodeSetup();
            } else {
                updateZeroNodeSetup(lineNode, newNode);
            }

            d->accept();
        }
    });

    QObject::connect(zn->btnZNUpdateClose, &QPushButton::clicked, [=] () {
        d->reject();
    });

}

void LocalZNTableModel::deleteZeroNodeFromSetup(const LocalZeroNodes &delNode) {

  QList<LocalZeroNodes> newZeroNodeList = zeroNodeSettings;
  zeroNodeSettings.clear();

  for(auto& it : newZeroNodeList) {
      if (!(delNode.status == it.status &&
          delNode.alias == it.alias &&
          delNode.ipAddress == it.ipAddress &&
          delNode.privateKey == it.privateKey &&
          delNode.txid == it.txid &&
          delNode.index == it.index)) {
          zeroNodeSettings.push_back(it);
      }
  }

  //Update Ui
  addLocalZNData();
  writeZeroNodeSetup();

}

void LocalZNTableModel::writeZeroNodeSetup() {

    QList<QString> zeroNodes;
    for(auto& it : zeroNodeSettings) {
        QString zeroNode = it.alias + " " + it.ipAddress + " " + it.privateKey + " " + it.txid + " " + QString::number(it.index);
        zeroNodes.push_back(zeroNode);
    }

    QString confLocation = Settings::getInstance()->zeroNodeConfWritableLocation();
    Settings::getInstance()->updateToZeroNodeConf(confLocation, zeroNodes);

}

void LocalZNTableModel::updateZeroNodeSetup(const LocalZeroNodes &lineNode, LocalZeroNodes &updatedNode) {
    QList<LocalZeroNodes> newZeroNodeList = zeroNodeSettings;
    zeroNodeSettings.clear();

    for(auto& it : newZeroNodeList) {
        if (!(lineNode.status == it.status &&
            lineNode.alias == it.alias &&
            lineNode.ipAddress == it.ipAddress &&
            lineNode.privateKey == it.privateKey &&
            lineNode.txid == it.txid &&
            lineNode.index == it.index)) {
            zeroNodeSettings.push_back(it);
        } else {
            zeroNodeSettings.push_back(updatedNode);
        }
    }

    //Update Ui
    addLocalZNData();
    writeZeroNodeSetup();
}

void LocalZNTableModel::updateZNPrivKeySetup(Ui_znsetup* zn, QString* newKey) {
    zn->txtZNPrivateKey->setText(*newKey);
}

void LocalZNTableModel::updateZNOutput(Ui_znsetup* zn) {
    if (!outputs->empty()) {
          if (outputIndex + 1 >= outputs->length()) {
            outputIndex = 0;
          } else {
            outputIndex++;
          }
          zn->txtZNOutput->setText(outputs->at(outputIndex).txid);
          zn->txtZNIndex->setText(QString::number(outputs->at(outputIndex).index));
    }
}

bool LocalZNTableModel::isLocal(QString txid) {

  for (auto it : zeroNodeSettings) {
      if (txid == it.txid)
          return true;
  }

  return false;

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

void LocalZNTableModel::updateAllLZNData() {
    auto newmodeldata = new QList<LocalZeroNodes>();

    if (znData != nullptr) std::copy(znData->begin(), znData->end(), std::back_inserter(*newmodeldata));

    // Sort by reverse time
    std::sort(newmodeldata->begin(), newmodeldata->end(), [=] (auto a, auto b) {
        return a.index < b.index; // reverse sort
    });

    // And then swap out the modeldata with the new one.
    delete modeldata;
    modeldata = newmodeldata;

    dataChanged(index(0, 0), index(modeldata->size()-1, columnCount(index(0,0))-1));
    layoutChanged();
}

 int LocalZNTableModel::rowCount(const QModelIndex&) const
 {
    if (modeldata == nullptr) return 0;
    return modeldata->size();
 }

 int LocalZNTableModel::columnCount(const QModelIndex&) const
 {
    return headers.size();
 }


 QVariant LocalZNTableModel::data(const QModelIndex &index, int role) const
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
        case 0: return dat.status;
        case 1: return dat.alias;
        case 2: return dat.ipAddress;
        case 3: return dat.privateKey;
        case 4: return dat.txid;
        case 5: return dat.index;
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


 QVariant LocalZNTableModel::headerData(int section, Qt::Orientation orientation, int role) const
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

QString LocalZNTableModel::getLZNStatus(int row) const {
    return modeldata->at(row).status;
}

QString LocalZNTableModel::getLZNAlias(int row) const {
    return modeldata->at(row).alias;
}

QString LocalZNTableModel::getLZNIpAddress(int row) const {
    return modeldata->at(row).ipAddress;
}

QString LocalZNTableModel::getLZNPrivateKey(int row) const {
    return modeldata->at(row).privateKey;
}

QString LocalZNTableModel::getLZNTxid(int row) const {
    return modeldata->at(row).txid;
}

qint64 LocalZNTableModel::getLZNIndex(int row) const {
    return modeldata->at(row).index;
}
