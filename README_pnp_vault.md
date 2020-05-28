# Pretty naive privacy vault
Naive vault was created to keep sensitive information as passwords in local storage in unreadable way. It's based on repeated shuffling of data in a way that naive attacker will be not able to read stored secrets. Keys are hashed, so are never known, and secrets are divided into single letters to be stored on 15 files next to hashed keys. Each time, when new entry is added to the store, secret files are reshuffled, so attacker cannot deduct from sequence of lines. As typisal system will keep little infrmation it's recommended ot generate noise data before use.

# Usage

```
pnp_vault.sh 
usage: pnp_vault save|read|delete key [value] [privacy]

, where
privacy user|host|script with default user
```

Generate noise data.

```
pnp_vault_test.sh 10
Save test:++++++++++
Replace test:++++++++++
OQSkWfMl l^X.+K7Y*y=zY7*/Ma~n'o+-:"ya(DC}
j9aXJFmf ')5ea)2pJq#(GV`%"lkq|v.M*9^{8u!l
MYmyIgmS ,?NoSlZ)C+g7ODeg0P2_h;3@a-~XE[zj
GLAGkvhp }9n=PHo|_26Hz30E<ryV[xq~zk5W@B1?
zuL5r-uy S+.n[,fe&7J7MEU$'1!)S(?9QHBL]F^A
7SEZCerQ 3YWz/xnfQA*&&5B[~Z7d6&)qZ^h#Yyl-
-rogvteC 9trC{"jQIvc"/;)>!fv9w7#y}~<33Q}(
FD9lkX87 ,FICNw"DbuQdFd9/<u(s,w6xg{V2=[83
0J3_r_yY H"p.*o%wMq@v'@6:)Q,W01m16kl!T5]I
amVl8BLp Lcw(cqK7uU}cJ/>&'iFJb&?[liw,M~w|
CGKjC0w4 >a}o?VG?w`5g37cl&"%,k|S^3h|bi<<W
w0Qu1ioC Zt1rqY%'-q6Pb$pg+nUgnyrZE+M/GGon
hVWgCUSC |-MxlvlCrN}dBWs).-/aAL.xz>~+A:3T
IUbQlo0J =%'~O}A,S,+v-wY+OH=6=Bln*o@0_%Im
5Wf3g_Ot *Y?EJwh"OLxV-V!sehr9L1ODZtNpPXEa
rKz_naOH /[PX<y2#;c%|*y8MGmq+!QT9'T@1HDip
sbvPi0__ "yzy"]3Fu6RJWkmKqe(ln_JKQ"XW0,--
E4C8SClL ':24v&W*"=S&l19Kjo0cCCy9!-Od[Q1m
L9vC_Yl4 %Dg("dal^qhQ17)rc~H=czY3-BzyovEG
hY8bBSYo n2va[lEqMIW]2OH`<.BDQ+TQ8-cu^]EG
Done.
```

Save password for john_smith at server1:

```
pnp_vault.sh save john_smith@server1 welcome1

```

Read the password:

```
pnp_vault.sh read john_smith@server1
welcome1
```

Delete stored secret:

```
pnp_vault.sh delete john_smith@server1
pnp_vault.sh read john_smith@server1

```

# Privacy levels
Data may be stored on one out of three available provacy levels. Lowest one: host makes it possible to read data by oneone of the host, as seed is generated out of hostname and i-node of /etc/. User level gets seed as combination of hostname and i-node of user's home. And the script one uses calling script i-node with combination of the hostanme. All of them uses the same set of data, having keys hashed in such way that privacy levels separates readings.


```
pnp_vault.sh save john_smith@server1 welcome1 user

pnp_vault.sh read john_smith@server1 user
welcome1

pnp_vault.sh read john_smith@server1 host

```

# Error codes
Zero is returned when all is good, and 1 or above in case of error. No data is signalled by 1.

```
pnp_vault.sh read john_smith@server1 host

echo $?
1
```

# Call from other script
One may call script as shell script or source it from own script. Sourcing is mandatory to use script level privacy. Having pnp_vault sourced, use functions in place od scripts callouts.

```
source pnp_vault.sh
read_secret john_smith@server1
welcome1
read_secret john_smith@server1 host

delete_secret john_smith@server1

read_secret john_smith@server1

```

# Algorithm
Algorithm used in pnp-vault is known, and everyone knowing parameters will be able to read secrets. So, what is the trick? First of all, keys are never known, as each key is hashed before string in vault. Even owner of the data is not able to read set of keys.

```
key_stored = sha256(key)
```

Values are divided into letters to be stored in separate files. Algorithm computes routing array as hash from key prefixed by hostname. Hostname is added to increase length of the string, however most probably it adds to value.

```
routing_array = sha256(hostname+key)
```

N-th letter of the value will be stored in data file pointed by n-th position on the routing array passed through hash of applied seed. 


```
data_file_pointer = routing_array[n]
data_file_id = seed[data_file_pointer]
save value[n] to data_file(data_file_id)
```

Having target file, pnp_valult computes local hash to be used in the file. Hash is mainly based on a key with two more element to generate unique hash per value character. Trivial grep trough all files will give attacker nothing.

```
local_hash = sha256( data_file_id, value_char_position, key )
```

After adding data, line shuffling is performed on a data file, so attacker cannot read from sequence of lines. 

# Seed
Algorithm is not hidden, and its strength comes from complexity of performed computations and hashes used to store keys. Anyway w/o adding seed data to the procedure anyone having the code may be able to decipher stored data. As you see routing to file and final hash is computed using seed information which is external to the code. Interesting is that seed is not stored in a filesystem, and it's not required to provide it during start in any form. Attacker copying all data will not get the seed. The trick is based on seed associated to filesystem - it's i-node number of script using the vault or computer's /etc directory. Both are unique per computer. Third level is the weakest one - based on name of the computer. 

# How strong is the algorithm?
How strong is above? Strong enough for amateur, and probably not a big issue for professional mathematician doing ciphers for life. Good point is that storage keeps rather small amount of data. It's designed to keep passwords, maybe private keys. Anyway, it's better than keeping in files protected by OS permissions. Attacker reaching the host will not be able to use this data in quick way. Data copied out of the computer is useless, unless attacker will be smart enough to retrieve seeds, what is quite unexpected for i-node information. Lowest privacy level, based on hostname seed seems to be trivial to break, however even with this one attacker will not read all data from secret files w/o knowing key names. 

# How safe is data storage?
Data is modified during save and delete operations. All data modification sections are locked to gain exclusive access. Data modification is always done on a copy of data to be moved to actual data once completed. Broken work will be rolled back during next start of the save or delete script.

# Data storage
All files are stored in ~/.pnp/secret in file 1, 2, ..., f

```
ls ~/.pnp/secret 
2  4  5  6  7  8  9  b  c  f
```

Let's take a look inside of files:

```
cat ~/.pnp/secret/* | sort | head -10
000d540123eba36f979ff0a9ca5b48061aeef76f76edc6e3cc210f30068497a1 W
000fc91b5ec35c6148ba6bbfae5cc01c0ffa07c6a2043e20b4a82f0d45a71e54 W
00119d32a33f8cd8f100cd90026b40c39ed6c0012e280468f87b26f7358b3709 W
0016ca6cc19ce8aae5bb656ac9e9eede3e0e10af3b182d4230dde0d44400a5ed w
0018dab611db05e695326ce20db7cbde14e8cb761922a827967937487c7298ba b
00194ba20eea57c81d48ce6956efbe7e798417cdcc49a4528a50e0de078f3a28 P
001b14312216cfcbe511d292d8b608563bc103f8bdafd04c5833ea4e85b611a2 C
00224306e49371ba0721562ffb4dbe68f48361fb6e040a99fe6d68abad01a5fe e
00232677166d8bcecc6361ee24c2756cbc40cd2f4ff4dbee7df87c846de891aa c
0026f0cf7d1f4a7edc836b0f424802ebb5a0d7d218e1de5f29293e4d0406f189 y
```

# Author
rstyczynski@gmail.com
Apache 2.0 License

