#include "filehelper.h"
#include <QFile>
#include <QDebug>

FileHelper::FileHelper(QObject *parent) : QObject(parent)
{

}

void FileHelper::deleteFile(QString path)
{
    qDebug() << path.mid(7);
    QFile::remove(path.mid(7));
}
