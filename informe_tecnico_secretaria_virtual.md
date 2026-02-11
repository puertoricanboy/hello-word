# Informe técnico: cómo construir una secretaria virtual

## 1) Objetivo, alcance y supuestos

Una **secretaria virtual** es un asistente conversacional orientado a productividad que:
- recibe solicitudes por voz y/o texto,
- entiende la intención del usuario,
- ejecuta acciones en herramientas corporativas (calendario, email, CRM, tareas, tickets),
- responde en lenguaje natural con trazabilidad, control de acceso y privacidad.

### Alcance funcional incluido
- Requisitos y casos de uso.
- Personas y workflows.
- Voz (STT/TTS), NLU/NLP, scheduling/calendario, correo, automatización, integraciones.
- Seguridad, privacidad, soporte multilingüe.
- Opciones de stack y arquitectura.
- Comparativa de proveedores.
- Plan de implementación con hitos, roles, esfuerzo y presupuesto.
- QA, KPIs, monitorización y logging.
- Compliance (GDPR y leyes locales), retención y consentimiento.
- Ejemplos de intents/entidades y diálogos.
- Despliegue y escalado.
- Componentes open source y pseudocódigo del flujo `speech → intent → action → response`.

### Supuestos no especificados por negocio
- Plataformas objetivo: no especificadas.
- Presupuesto: no especificado.
- Idiomas adicionales: no especificados.
- Dominio/vertical: no especificado.
- Modelo operativo (B2B/B2C, interno/externo): no especificado.

> Recomendación de producto: separar desde el inicio la **capacidad conversacional** (entender/responder) de la **capacidad de ejecución** (hacer acciones seguras) para evitar un bot “que conversa” pero no completa tareas.

---

## 2) Requisitos funcionales y casos de uso

### Requisitos mínimos de MVP
1. **Entrada/salida multicanal**: chat (web/app, Slack/Teams/WhatsApp) y voz opcional (PSTN/VoIP).
2. **Comprensión de intención y entidades**: fecha/hora, participantes, prioridad, asunto, etc.
3. **Orquestación de acciones**: integraciones API, reintentos, confirmaciones para acciones sensibles.
4. **Gestión de contexto**: estado de sesión, memoria de conversación y preferencias con retención controlada.
5. **Seguridad y acceso**: OAuth2/OIDC, RBAC, cifrado, auditoría, gestión de secretos.

### Casos de uso de mayor ROI
- **Agenda y coordinación**: crear/reprogramar/cancelar reuniones con confirmación.
- **Triage de email**: clasificar, sugerir borradores, responder con aprobación.
- **Tareas y seguimiento**: recordatorios, pendientes, follow-up automático.
- **Recepción telefónica**: agendamiento y autoservicio en llamada.
- **Handoff humano**: escalamiento por baja confianza o políticas.

---

## 3) Personas y workflows

### Personas
- **Profesional con agenda saturada**: prioriza rapidez y baja fricción.
- **Asistente humano/operaciones**: usa copiloto y mantiene control final.
- **IT/Seguridad**: exige trazabilidad, RBAC y control de datos.
- **Compliance/Legal**: exige base legal, minimización y retención proporcional.

### Workflow de voz (agendar reunión)
1. Usuario habla (app o llamada).
2. STT en streaming con detección de fin de turno.
3. NLU/LLM detecta intención + entidades.
4. Orquestador completa slots faltantes y solicita confirmación.
5. Ejecuta acción (calendar API) + auditoría.
6. Responde por voz y opcionalmente resume por email/SMS.

### Workflow de email (respuesta asistida)
1. Clasificación y sugerencia de respuesta.
2. Validación de políticas (firma, disclaimer, aprobación).
3. Envío o creación de tarea alternativa.

---

## 4) Arquitectura de referencia

## Capa de canales
- Web/app chat, WhatsApp/Slack/Teams.
- Telefonía via proveedor CPaaS (ej. Twilio) con streaming de audio.

## Capa de voz
- **STT** en tiempo real (parciales/finales).
- **TTS** de baja latencia con voz configurable.
- Soporte de barge-in e interrupción.

## Capa de inteligencia
- **NLU determinista** (intents/slots) para acciones críticas.
- **LLM + tools** para lenguaje abierto, resumen y redacción.
- **Policy Engine** para autorización y guardrails.

## Capa de ejecución
- Conectores a calendario, email, CRM, tareas.
- Idempotencia, reintentos y circuit breakers.

## Capa de datos
- DB transaccional (usuarios, permisos, estado).
- Logs/eventos de auditoría.
- Memoria semántica opcional con políticas de retención.

## Capa de observabilidad y seguridad
- OpenTelemetry (traces/métricas/logs).
- RBAC, cifrado en tránsito/descanso, secretos, alertas.

### Presupuesto de latencia (objetivo orientativo)
- VAD/endpointing: 100–300 ms.
- STT parcial/final: 200–900 ms.
- NLU/LLM: 150–1200 ms.
- Acción externa (API): 200–1500 ms.
- TTS inicial: 100–600 ms.

Objetivo UX: feedback inmediato si una operación supera ~1 segundo.

---

## 5) Opciones de stack tecnológico

### Ruta A: Managed-first (rápida salida)
- Cloud STT/TTS + LLM API + iPaaS para integraciones.
- Pros: velocidad de implementación.
- Contras: dependencia de proveedor y mayor análisis de retención de datos.

### Ruta B: Híbrida
- Voz/LLM gestionados, pero datos críticos y auditoría en infraestructura propia.
- Pros: equilibrio entre time-to-market y control.
- Contras: complejidad media.

### Ruta C: Self-host / open-source
- STT local (Whisper), NLU con Rasa, workflows propios (Temporal/n8n).
- Pros: mayor control de datos.
- Contras: mayor costo operativo (SRE/MLOps).

### Componentes open-source sugeridos
- Whisper (MIT) para STT local.
- Rasa (Apache 2.0) para intents/entidades y diálogo.
- OpenTelemetry para observabilidad.
- OWASP ASVS + Logging Cheat Sheet como baseline de seguridad.

---

## 6) Comparativa resumida de proveedores

| Proveedor | Fortalezas | Riesgos/Trade-offs | Mejor uso |
|---|---|---|---|
| Google Cloud | STT/TTS sólidos, ecosistema amplio | Dependencia cloud, revisar data logging | Bots empresariales multicanal |
| AWS | Integración nativa con stack AWS (Lex/Transcribe/Polly) | Curva de configuración y gobierno | Empresas centradas en AWS |
| Azure | Fuerte postura enterprise y M365 | Complejidad de configuración | Organizaciones Microsoft-first |
| OpenAI API | Calidad LLM/audio y rapidez de integración | Gobierno de datos y costos por uso | Comprensión/redacción avanzada |
| Twilio | Excelente capa de telefonía y media streams | Es capa de comunicaciones, no NLU final | Voz PSTN/VoIP en producción |
| Rasa (OSS) | Control y personalización | Necesita equipo técnico sólido | Entornos con restricciones de datos |
| Zapier/Make | Integración rápida de apps | Riesgo extra de tokens/superficie | Automatización rápida no crítica |

---

## 7) Plan de implementación

### Fase 0: Descubrimiento (2–4 semanas)
- Casos de uso priorizados, mapa de riesgos y datos.
- Definir acciones permitidas + matriz de permisos.
- Decidir arquitectura (A/B/C) y políticas de retención.

### Fase 1: Prototipo (4–6 semanas)
- Chat + voz básica en un canal.
- Flujo STT→NLU→respuesta con handoff humano.
- Telemetría mínima y panel de errores.

### Fase 2: MVP ejecutable (6–10 semanas)
- Integración calendario + email con OAuth.
- Confirmaciones para acciones de impacto.
- Auditoría y RBAC básicos.

### Fase 3: Beta y hardening (6–8 semanas)
- Dataset de evaluación (conversaciones reales anonimizadas).
- Pruebas de carga, resiliencia y fallback.
- Revisión legal, DPA y retención final.

### Fase 4: Producción
- Escalado, on-call, runbooks, DR.
- Monitoreo 24/7, mejora continua por métricas.

### Equipo mínimo recomendado
- Product/Tech Lead.
- 1–2 Backend Integrations Engineers.
- 1 Conversational/ML Engineer.
- 1 DevOps/SRE.
- Security/Privacy (parcial o dedicado según industria).

### Rangos orientativos de presupuesto
- **Low (MVP simple)**: USD 60k–200k.
- **Medium (beta robusta)**: USD 250k–800k.
- **High (enterprise multi-región)**: USD 1.0M–3.0M+.

---

## 8) QA, KPIs, monitorización y logging

### Testing por capas
- Unit tests (normalización de fechas, reglas de permisos).
- Integration/contract tests (Calendar/Email/CRM).
- Conversational regression (“golden dialogs”).
- Carga/soak (p95/p99 de latencia y error).

### KPIs recomendados
- WER (voz).
- Intent accuracy + F1 de entidades.
- Task completion rate.
- Fallback/handoff rate y motivos.
- Latencia end-to-end p50/p95.
- Costo por tarea completada.

### Observabilidad mínima
- `conversation_id`, `turn_id`, `action_id` correlacionados.
- Traces por etapa (STT, NLU/LLM, tool/action, TTS).
- Logs con redacción de PII y acceso RBAC.

---

## 9) Seguridad, privacidad y compliance

### Principios clave
- Privacidad por diseño y por defecto.
- Minimización de datos y retención limitada.
- Consentimiento explícito para grabación/transcripción de voz.
- Auditoría de acciones con identidad y timestamp.

### GDPR / normativa local
- Definir rol de responsable/encargado.
- Firmar DPA con proveedores.
- Gestionar transferencias internacionales.
- Implementar mecanismos de derechos del titular (acceso, rectificación, supresión, etc.).

### Patrón de consentimiento en voz
1. Mensaje inicial de información y finalidad.
2. Opción de no aceptar y alternativa por humano/chat.
3. Registro del consentimiento (canal, timestamp, texto mostrado).
4. Borrado según política de retención.

---

## 10) Ejemplos de intents, entidades y diálogo

### Intents base
- `agendar_reunion`, `reprogramar_reunion`, `cancelar_reunion`
- `consultar_disponibilidad`
- `enviar_email`, `resumir_bandeja_entrada`
- `crear_tarea`, `consultar_pendientes`
- `opt_out_grabacion`, `ayuda`, `saludo`, `despedida`

### Entidades base
- `fecha`, `hora`, `duracion`, `participante`, `email`, `asunto`, `prioridad`, `ubicacion`, `zona_horaria`

### Mini diálogo
- Usuario: “Agenda una reunión con Ana la semana que viene.”
- Asistente: “¿La quieres de 30 o 60 minutos, y en qué días?”
- Usuario: “30 minutos, martes por la tarde.”
- Asistente: “Perfecto. Veo 3:00 o 4:30 pm. ¿Cuál confirmo?”
- Usuario: “4:30 pm.”
- Asistente: “Listo, reunión creada y enviada la invitación.”

---

## 11) Pseudocódigo del flujo `speech → intent → action → response`

```python
def handle_voice_turn(call_id, audio_chunk, user_context):
    stream_buffer.add(audio_chunk)

    if not vad.end_of_utterance(stream_buffer):
        return None

    transcript, stt_conf = stt.transcribe(stream_buffer)
    intent, entities, nlu_conf = nlu.parse(transcript)

    decision = policy_engine.evaluate(
        user=user_context,
        intent=intent,
        entities=entities,
        confidence=nlu_conf,
    )

    if decision.blocked:
        return tts.speak("No puedo realizar esa acción con tus permisos.")

    if decision.requires_confirmation:
        prompt = clarifier.build_confirmation(intent, entities)
        return tts.speak(prompt)

    result = action_executor.run(
        intent=intent,
        entities=entities,
        user_context=user_context,
        idempotency_key=make_idempotency_key(call_id, intent, entities),
    )

    audit.log(call_id=call_id, intent=intent, entities=entities, result=result)
    return tts.speak(nlg.summarize(result))
```

---

## 12) Recomendación ejecutiva final

Para maximizar probabilidad de éxito:
1. Comenzar por **2–3 casos de uso de alto volumen** (agenda, email, tareas).
2. Aplicar patrón **“confirmar antes de ejecutar”** en toda acción externa.
3. Diseñar desde día 1 **gobierno de datos + observabilidad + auditoría**.
4. Elegir arquitectura **híbrida** como punto medio inicial (velocidad/control).
5. Establecer un ciclo de mejora por métricas (task completion, latencia, handoff, costo).

En la práctica, la ventaja competitiva no está solo en “usar un LLM”, sino en la **ejecución fiable y segura** de acciones reales en sistemas de negocio.
