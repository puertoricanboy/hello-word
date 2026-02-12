# Secretaria Virtual MVP

Aplicación mínima funcional para una secretaria virtual basada en texto, con arquitectura por capas:
- NLU básico (intención + entidades)
- motor de políticas
- ejecutor de acciones (agenda/email/tareas)
- API HTTP y UI web simple

## Ejecutar localmente

```bash
python -m app.main
```

Abrir: `http://localhost:8000`

## Endpoints
- `GET /` UI
- `POST /api/turn` procesa una solicitud de usuario
- `GET /api/state` devuelve estado en memoria

## Ejecutar tests

```bash
pytest -q
```
