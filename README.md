# Pixel To-Do

App Android de pendientes y hábitos con estética pixel. Cada misión cumplida da XP y oro, y con el oro construyes **Ciudad Pixel**: empiezas en una casita y creces hasta levantar el palacio municipal.

## Cómo funciona

- **Misiones** (una vez) y **hábitos diarios** (con rachas). La dificultad define la recompensa:

  | Dificultad | XP | Oro |
  |---|---|---|
  | Fácil | 50 | 10 |
  | Media | 150 | 25 |
  | Difícil | 300 | 50 |
  | Épica | 600 | 100 |

- **Niveles**: empiezas en nivel 1; el nivel n se alcanza con n × 1000 XP en total.
- **Oro**: se registra el total ganado cada día y tu récord diario.
- **Ciudad**: cada servicio (vivienda, empleo, escuela, agua, luz, basura) debe alcanzar para todos. La felicidad es el promedio de cobertura. Los vecinos llegan al completar misiones si hay casa y la felicidad es de 60% o más. Con 70% ganas +10% de oro y con 90%, +20%.
- **Meta**: el palacio municipal (nivel 10, 80% de felicidad, 30 habitantes y 3000 de oro).
- **Avance**: gráficas de XP y oro de los últimos 7 días.
- **Avatar** pixel personalizable.

Todo se guarda en el teléfono.

## Correrla

```
flutter pub get
flutter run
```

## Estructura

```
lib/
  main.dart                 app, encabezado y pestañas
  game/rules.dart           dificultades, niveles y catálogo de edificios
  game/game_state.dart      estado del juego y guardado
  ui/pixel.dart             paleta, tipografías y componentes pixel
  ui/sprites.dart           dibujo del avatar y los edificios
  ui/city_view.dart         ciudad animada
  screens/                  Misiones, Ciudad, Avance y Avatar
assets/fonts/               Silkscreen y Pixelify Sans (licencia OFL)
```
