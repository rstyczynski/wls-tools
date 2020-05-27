# wls-tools
Set of tools supporting technical aspects of working with Oracle Middleware.

* compare domains
* diff patches
* MFT error summary
* WLS error summary
* WLS users
* WLS top threads
* easy JFR

## Install

Put scripts in home directory of user owning Middleware processes.

```
sudo su - oracle
git clone https://github.com/rstyczynski/wls-tools.git
```

Having no git, use wget to download wls-tools release at given version.

```
sudo su - oracle
wget https://github.com/rstyczynski/wls-tools/archive/v0.2.1.tar.gz
tar -xzf v0.2.1.tar.gz
ln -s wls-tools-0.2.1 wls-tools
```

