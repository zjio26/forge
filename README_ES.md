[English](README.md) | [中文](README_CN.md) | [日本語](README_JA.md) | [Español](README_ES.md)

# Forge

> Forge — a solid harness-engineered workflow for Claude Code. Calidad impuesta por estructura, no por disciplina de prompts.

![License](https://img.shields.io/github/license/zjio26/forge) ![GitHub stars](https://img.shields.io/github/stars/zjio26/forge?style=social)

```
┌─────────────────────────────────────────────────────────┐
│  $ /forge:forge Build a rate-limited API gateway with    │
│            JWT auth, Redis token revocation, request     │
│            dedup, and Prometheus metrics                 │
│                                                         │
│  🟦 Planning...      ✅ Plan complete                   │
│  🟩 Wave 1/3 Dev...  ✅ 12 unit tests passed            │
│  🟨 Wave 1/3 Test... ✅ PASS (unit: 12/12, int: 3/4)   │
│  🟩 Wave 2/3 Dev...  ✅ 8 unit tests passed             │
│  🟨 Wave 2/3 Test... ❌ 2 bugs → 🟩 Fix → ✅ PASS      │
│  🟩 Wave 3/3 Dev...  ✅ 6 unit tests passed             │
│  🟨 Wave 3/3 Test... ✅ PASS                            │
│  🟨 Integration...   ✅ Full integration PASS            │
│  🟪 Learning...      4 new lessons → knowledge.md       │
│                                                         │
│  Forge completed! 26/26 unit tests passed.              │
└─────────────────────────────────────────────────────────┘
```

---

## Claude Code sin Forge duele — Forge lo corrige con estructura

Lo has vivido:

- **Código sin tests** — o tests que solo existen en papel. Si los humanos los saltan, los modelos también
- **Deriva de contexto** — a mitad de una tarea, olvida por dónde empezó
- **Arreglas A, rompes B** — sin verificación en bucle cerrado, los bugs se cascaden
- **Mismos errores, cada ejecución** — cero aprendizaje de errores pasados
- **Crash = empezar de cero** — sin checkpoint, sin recuperación, todo el trabajo perdido

Forge no le pide al modelo que "tenga cuidado". Suelda la disciplina de ingeniería en el workflow:

| Mecanismo | Cómo funciona |
|------------|---------------|
| **Bucle cerrado Dev→Test→Fix** | Dev debe pasar Test. ¿Falla? Fix. ¿Falla otra vez? Fix otra vez, hasta 3 rondas. Veredicto: PASS/FAIL — nada de "parece bien" |
| **Escalado por Waves** | Requisitos grandes se dividen automáticamente en Waves. Cada wave obtiene un par fresco de Dev+Test. Handoff entre waves vía archivos de handoff |
| **Acumulación de experiencia** | Learner extrae lecciones a knowledge.md. Planner las referencia la próxima vez. Más inteligente con cada ejecución |
| **Recuperación ante crashes** | Cada paso escribe un checkpoint en state.json. Re-ejecuta el mismo comando, continúa desde donde lo dejaste. Cero líneas perdidas |
| **Think Before Code** | Planner detecta ambigüedades y te pregunta primero. No más codificando en la dirección equivocada por una hora |
| **Aislamiento de contexto** | Coordinator solo rastrea rutas y estado — nunca lee contenido intermedio. El contexto se mantiene ligero |

## Arquitectura

```
User ──"/forge requirement"──▶ Coordinator
                                  │
                       ┌──────────┤
                       ▼          │
                  🟦 Planner     │
                  plan + waves   │
                       │          │
                       ▼          │
               ┌─── Wave Loop ──────────────────┐
               │                                │
               │  🟩 Dev W1 ──▶ 🟨 Test W1     │
               │       ▲              │         │
               │       │           FAIL?        │
               │       └── Fix ──────┘          │
               │       (same agent,             │
               │        context preserved)      │
               │              │                 │
               │            PASS ──▶ next wave  │
               │                                │
               └────────────────────────────────┘
                                  │
                                  ▼
                       🟨 Full Integration Test
                                  │
                                  ▼
                       🟪 Learner ──▶ 📚 knowledge.md
```

| Agent | Model | Rol |
|-------|-------|-----|
| Coordinator | — | Despacha agentes, rastrea rutas y estado — nunca lee contenido intermedio |
| Planner | sonnet | Descompone requisitos, define criterios de aceptación, detecta ambigüedades |
| Dev | sonnet | Implementa features, escribe unit tests, corrige bugs — solo lo que está en el plan |
| Test | haiku | Unit tests deben pasar, integration tests best-effort, informes de bugs precisos |
| Learner | haiku | Extrae lecciones, deduplica, máximo 5 por ejecución |

---

## Filosofía de diseño: Harness Engineering

Calidad a través de restricciones estructurales, no autodisciplina del modelo:

- **Estructura > Fuerza de voluntad** — Las reglas viven en el workflow, no en los prompts. Si una regla no puede aplicarse estructuralmente, rediseña el workflow
- **Bucle cerrado > Bucle abierto** — Dev→Test→Fix es obligatorio. Veredictos solo PASS/FAIL, nada de "debería estar bien"
- **Aislamiento > Hinchazón** — Coordinator rastrea rutas y estado, nunca contenido. Cada wave obtiene contexto independiente
- **Recuperable > Reintentable** — Checkpoint de estado en cada paso. Reanuda desde el punto de interrupción tras un crash, no empieces de cero
- **Solo lo solicitado** — Cada línea modificada se rastrea hasta el plan o un fix de bug. Sin extras, sin mejoras especulativas

---

## Inicio rápido en 5 minutos

**Requisito previo**: [Claude Code CLI](https://docs.anthropics.com/en/docs/claude-code) instalado.

**Instalación por plugin (recomendado):**

```
/plugin marketplace add zjio26/forge
/plugin install forge
```

**Instalación offline:**

```bash
git clone https://github.com/zjio26/forge.git && cd forge && bash install.sh
```

**A ejecutar:**

```
/forge:forge Build a rate-limited API gateway with JWT auth, Redis token revocation, request dedup, and Prometheus metrics
```

> El modo plugin usa `/forge:forge`, la instalación manual usa `/forge`. Esa es la única diferencia.

---

## Ejemplos de uso

**Construir una feature no trivial:**

> **Tú**: `/forge:forge Implement a full user registration→login→order→payment flow with JWT auth, inventory locking, and timeout auto-release`
>
> **Forge**: Planner descompone en 5 subtareas, 3 waves → Wave 1 construye modelos de datos y auth → Wave 2 maneja órdenes e inventario → Wave 3 maneja pagos y timeouts → test de integración completo → Learner extrae 3 lecciones

**Refactorizar con red de seguridad:**

> **Tú**: `/forge:forge Refactor the database layer to use connection pooling, compatible with all existing callers`
>
> **Forge**: Planner identifica módulos afectados → Dev hace cambios quirúrgicos → Test ejecuta suite completa de unit + integration → regresión capturada por auto-Fix → cero intervención manual

**¿Crash? Reanuda:**

> **Tú**: `/forge:forge` (simplemente re-ejecuta el mismo comando)
>
> **Forge**: Lee state.json → reanuda desde el último checkpoint → ni una sola línea perdida

---

## Estructura del proyecto

```
forge/
├── agents/                  # Definiciones de agentes especializados
│   ├── planner.md           # Descomposición de requisitos — sonnet, define criterios de aceptación
│   ├── dev.md               # Implementación + unit tests + fixes — sonnet, solo trabajo planificado
│   ├── test.md              # Verificación de tests — haiku, unit test fail = FAIL
│   └── learner.md           # Extracción de experiencia — haiku, dedup, máx 5 por ejecución
├── skills/forge/
│   ├── SKILL.md             # Orquestador Coordinator — solo rastrea rutas y estado
│   └── knowledge.md         # Base de conocimiento de experiencia — auto-actualizada por Learner
├── install.sh               # Instalador offline
└── CLAUDE.md                # Instrucciones del proyecto
```

Artefactos en tiempo de ejecución (en el directorio `.forge/` del proyecto destino, gitignored):

```
.forge/
├── {slug}-plan.md              # Plan de desarrollo
├── {slug}-waves.json           # Agrupación por waves
├── {slug}-dev-W{n}.md          # Registro de dev por wave
├── {slug}-test-W{n}.md         # Informe de tests por wave
├── {slug}-handoff-W{n}.md      # Archivo de handoff por wave
├── {slug}-test-integration.md  # Informe de test de integración completo
├── {slug}-state.json           # Checkpoint de estado (recuperación ante crash)
└── {slug}-metrics.json         # Métricas en tiempo de ejecución
```

---

## Contribuir y licencia

PRs bienvenidos. Las definiciones de agentes y la lógica de orquestación son el núcleo — lee los principios de diseño de CLAUDE.md antes de modificar.

- Modificar definiciones de agentes: cada archivo debe ser auto-contenido, las referencias de rutas usan `.forge/`
- Modificar SKILL.md: Coordinator solo rastrea rutas y estado, nunca lee contenido
- Modificar install.sh: mantener sincronizados los mapeos de rutas origen-destino

[Licencia MIT](LICENSE)
