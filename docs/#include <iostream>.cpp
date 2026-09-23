#include <iostream>
#include <vector>
#include <cstdlib>
#include <ctime>

using namespace std;

void llenar(vector<int>& notas, int cantidad) {
    for (int i = 0; i < cantidad; i++) {
        int nota = rand() % 11; // Número entre 0 y 10
        notas.push_back(nota);
    }
}

void mostrar(const vector<int>& notas) {
    cout << "\nNotas: ";

    for (int nota : notas) {
        cout << "[ " << nota << " ] ";
    }

    cout << endl;
}

int main() {
    srand(time(nullptr));

    vector<int> notas;
    int cantidad;

    cout << "Cuantas notas quieres generar? ";
    cin >> cantidad;

    if (cantidad <= 0) {
        cout << "La cantidad debe ser mayor que cero." << endl;
        return 1;
    }

    llenar(notas, cantidad);
    mostrar(notas);

    return 0;
}