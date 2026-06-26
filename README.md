# Breakout

Clon del clásico **Breakout** de Atari (1976) escrito en [Odin](https://odin-lang.org/) usando [raylib](https://www.raylib.com/) vía el binding `vendor:raylib`.

## Estado actual

- [x] Paleta controlable con teclas `A`/`D`
- [x] Pelota con rebote en bordes de pantalla
- [x] Colisión pelota ↔ paleta con ángulo variable según punto de impacto
- [x] Grid de ladrillos (6 filas × 14 columnas)
- [x] Colisión pelota ↔ ladrillos con destrucción de ladrillos
- [x] Sistema de vidas y game over

## Requisitos

- [Odin](https://odin-lang.org/docs/install/) (compilador)
- `vendor:raylib` (incluido con Odin — se bajan los binarios automáticamente al compilar)

## Compilar y ejecutar

```bash
odin run .
```

Esto compila y lanza el juego en una ventana de 720×640 a 60 FPS.

## Controles

| Tecla                  | Acción                      |
|------------------------|-----------------------------|
| `A` / flecha izquierda | Mover paleta a la izquierda |
| `D` / flecha derecha   | Mover paleta a la derecha   |

## Roadmap

1. **Sistema de vidas y Game Over** — la pelota se reposiciona, se pierde una vida al caer
2. **Sistema de puntuación y HUD** — puntos por ladrillo destruido, indicadores en pantalla
3. **Estados del juego** — Start Screen, Playing, Pause, Game Over
4. **Lanzamiento manual** — Barra espaciadora para soltar la pelota al inicio de cada vida
5. **Niveles múltiples** — distintas disposiciones de ladrillos, dificultad progresiva
6. **Controles adicionales** — tecla `P`/`Esc` para pausa
7. **Audio** — efectos de sonido (rebotes, destrucción, game over)
8. **Power-ups** — Wide Paddle, Multiball, Slow Ball, Extra Life, Sticky Paddle, Laser
9. **Efectos visuales** — partículas, colores por fila de ladrillos, screen shake
10. **High score persistente**
