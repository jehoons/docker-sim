# Fastfacile
Facile is a convenient tool for generating an ODE model for research. Facile is developed from Swain lab (Siso-Nadal et al., 2007). Fastfacile is extension codes for Facile. fastfacile generates a cmex code for fast excution of ode engine. 

## Install 
### Step 1. facile
먼저 라이브러리를 설치한다. 
```bash 
sudo cpan -i Class::Std
```
다음으로 facile을 설치한다. 그 다음에서는 bin, facile 경로를 실행경로에 추가한다. 

### Step 2. vfgen

```bash 
cp vfgen-2.5.0-linux-x86_64 bin/vfgen
chmod +x bin/vfgen
```

### Step 3. sundials 
vfgen이 지원하는 sundials의 버젼은 2.3.0 에서 2.7.0 까지이다. 

option 1. sundials-2.3.0
```bash 
tar xvf sundials-2.3.0.tar.gz 
cd sundials-2.3.0
./configure --with-cflags="-O4 -fPIC" --prefix=/usr/local/sundials-2.3.0
make clean && make -j 20 
sudo make install
cd ..
rm -rf sundials-2.3.0
```

option 2. sundials-2.5.0
```bash
tar xvf sundials-2.5.0.tar.gz 
cd sundials-2.5.0
./configure --with-cflags="-O4 -fPIC" --prefix=/usr/local/sundials-2.5.0
make clean && make -j 20 
sudo make install
cd ..
rm -rf sundials-2.5.0
```

### Step 4. Matlab801
```bash
tar xvf Matlab801Uz.tgz
cd Matlab801Uz/Matlab801
sudo ./install_linux -mode silent
```

### Step 5. gsl-2.2
```bash 
tar xvf gsl-2.2.tar.gz
cd gsl-2.2
./configure --with-cflags="-O4 -fPIC" --prefix=/usr/local/gsl-2.2
make clean && make -j 20 
```

## Reference
* Siso-Nadal, F., Ollivier, J.F., and Swain, P.S. (2007). Facile: a command-line network compiler for systems biology. BMC Syst Biol 1, 36.
