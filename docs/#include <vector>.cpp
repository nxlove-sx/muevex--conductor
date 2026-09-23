#include <vector>
#include <iostream>

using namspace std;


void llenar(vector <int>& notas){

    for(int i=0; i<notas.size(); i++){
        int x=rand() % 10 - 10;
        notas.push_back(x);
    }

void mostrar(vector <int>& notas){
        for(int i=0; i<notas.size(); i++){

            cout<<"[ "<<notas[i]<<" ]";
        }


    }
}


int main(){
    srand(time(0));

    vector <int> notas; 
    
    llenar(notas);
    mostrar(notas);

    return 0;
}
