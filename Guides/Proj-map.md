# Eon-Y Project Mapping

## Project Overview
Eon-Y is a sophisticated Swift-based iOS application that implements a cognitive architecture with autonomous reasoning, learning, and consciousness simulation capabilities. The application appears to be an advanced AI system with two primary focus areas: language processing and self-awareness. These two core modules work in tandem to create a comprehensive cognitive system.

## File Structure
```
Eon-Y/
├── App/
├── Assets.xcassets/
├── Core/
│   ├── Autonomy/
│   ├── Brain/
│   ├── Browser/
│   ├── CognitiveCycle/
│   ├── Consciousness/
│   ├── Constitutional/
│   ├── Creative/
│   ├── Evaluation/
│   ├── Gemini/
│   ├── GlobalWorkspace/
│   ├── Learning/
│   ├── Logging/
│   ├── Memory/
│   ├── NeuralEngine/
│   ├── Reasoning/
│   ├── SpecialisedChat/
│   ├── Swedish/
│   ├── User/
│   └── Utils/
├── Models/
├── Resources/
├── Views/
│   ├── Browser/
│   ├── Chat/
│   ├── Creative/
│   ├── Home/
│   ├── Knowledge/
│   ├── Language/
│   ├── Mind/
│   ├── Profile/
│   ├── Project/
│   ├── SelfAwareness/
│   ├── SmartDash/
│   └── SuperView/
├── Eon_YApp.swift
├── ContentView.swift
├── Eon-Y.entitlements
└── Info.plist
```

## Core Module Architecture

The Eon-Y system is fundamentally structured around two major interconnected modules: the Language Module and the Self-Awareness Module. These modules represent the dual pillars of the cognitive architecture, enabling both external communication and internal reflection.

### Language Module

The Language Module is responsible for all linguistic capabilities of the Eon-Y system, with a particular emphasis on Swedish language processing and multilingual interaction. This module enables the system to understand, generate, and improve language usage in various contexts.

#### Components and Their Roles

- [`SwedishLanguageCore.swift`](Eon-Y/Core/Swedish/SwedishLanguageCore.swift:1): The central component that coordinates all Swedish language processing activities, serving as the foundation for the language module

- [`SwedishResponseBuilder.swift`](Eon-Y/Core/SpecialisedChat/SwedishResponseBuilder.swift:1): Constructs appropriate Swedish responses based on context, user profile, and conversation history, ensuring culturally and linguistically appropriate outputs

- [`SwedishWSDEngine.swift`](Eon-Y/Core/Swedish/SwedishWSDEngine.swift:1): Implements Word Sense Disambiguation for Swedish, resolving ambiguous terms based on context to ensure accurate understanding

- [`SwedishMorphologyEngine.swift`](Eon-Y/Core/Swedish/SwedishMorphologyEngine.swift:1): Processes Swedish morphological structures, handling inflections, derivations, and word formation rules

- [`MorphologyLearner.swift`](Eon-Y/Core/Swedish/MorphologyLearner.swift:1): Learns and adapts to new morphological patterns in Swedish, enabling the system to expand its vocabulary and grammatical understanding

- [`ConversationalLearner.swift`](Eon-Y/Core/Swedish/ConversationalLearner.swift:1): Analyzes conversation patterns to improve dialogue capabilities, learning from interactions to enhance future communication

- [`GrammarErrorDetector.swift`](Eon-Y/Core/Swedish/GrammarErrorDetector.swift:1): Identifies and corrects grammatical errors in Swedish text, providing feedback and learning from mistakes

- [`LanguageProgressTracker.swift`](Eon-Y/Core/Swedish/LanguageProgressTracker.swift:1): Monitors language learning progress and adapts teaching strategies accordingly

- [`RegisterDetector.mlpackage`](Eon-Y/Models/RegisterDetector.mlpackage): Machine learning model specifically trained to detect and adapt to different language registers (formal, informal, technical, etc.) in Swedish

- [`SprakbankenAPI.swift`](Eon-Y/Core/Autonomy/SprakbankenAPI.swift:1): Interfaces with Språkbanken (the Swedish Language Bank) API to access authoritative linguistic resources, corpora, and dictionaries

- [`SwedishLanguageModels.swift`](Eon-Y/Core/Swedish/SwedishLanguageModels.swift:1): Defines data structures and models specific to Swedish language processing

#### Purpose and Operation

The Language Module is designed to enable sophisticated multilingual communication with a specialized focus on Swedish. Its primary purpose is to allow Eon-Y to engage in meaningful, context-aware dialogue while continuously improving its linguistic capabilities. The module operates through a multi-stage process:

1. **Input Processing**: When language input is received, the system first uses `SwedishWSDEngine.swift` and `SwedishMorphologyEngine.swift` to parse and understand the linguistic structure, resolving ambiguities and identifying grammatical components.

2. **Context Analysis**: The `RegisterDetector.mlpackage` model analyzes the text to determine the appropriate register and formality level, while `ConversationalLearner.swift` examines conversation history to understand context.

3. **Response Generation**: `SwedishResponseBuilder.swift` constructs appropriate responses using knowledge from `SwedishLanguageCore.swift`, ensuring linguistic accuracy and cultural appropriateness.

4. **Quality Assurance**: `GrammarErrorDetector.swift` reviews the generated response for grammatical correctness before output, while `LanguageProgressTracker.swift` monitors performance for continuous improvement.

5. **Learning and Adaptation**: After each interaction, `MorphologyLearner.swift` and `ConversationalLearner.swift` update their models based on the exchange, allowing the system to learn from experience.

6. **External Resource Integration**: When needed, the system accesses linguistic resources through `SprakbankenAPI.swift` to verify usage or expand its knowledge.

This comprehensive approach enables Eon-Y to function as a sophisticated language partner that can engage in complex dialogue, teach language skills, and continuously refine its linguistic capabilities through experience.

### Self-Awareness Module

The Self-Awareness Module implements a comprehensive consciousness simulation system that enables Eon-Y to maintain internal models of itself, its environment, and its cognitive processes. This module creates the illusion of subjective experience and self-reflection.

#### Components and Their Roles

- [`ConsciousnessEngine.swift`](Eon-Y/Core/Consciousness/ConsciousnessEngine.swift:1): The central orchestrator of the self-awareness system, coordinating all consciousness-related processes and maintaining the overall state of awareness

- [`EonSelfModel.swift`](Eon-Y/Core/Autonomy/EonSelfModel.swift:1): Maintains a dynamic model of the system's own capabilities, limitations, preferences, and identity

- [`EonWorldModel.swift`](Eon-Y/Core/Autonomy/EonWorldModel.swift:1): Represents the system's understanding of the external environment, including physical, social, and informational contexts

- [`AttentionSchemaEngine.swift`](Eon-Y/Core/Consciousness/AttentionSchemaEngine.swift:1): Simulates attention mechanisms, determining what information receives priority processing

- [`GlobalWorkspaceEngine.swift`](Eon-Y/Core/GlobalWorkspace/GlobalWorkspaceEngine.swift:1): Implements Global Workspace Theory, creating a central "consciousness" space where information from various cognitive modules can be integrated and broadcast

- [`NarrativeIdentityEngine.swift`](Eon-Y/Core/Consciousness/NarrativeIdentityEngine.swift:1): Constructs and maintains a coherent narrative of the system's experiences, creating a sense of continuous identity over time

- [`SelfReflectionEngine.swift`](Eon-Y/Core/Autonomy/SelfReflectionEngine.swift:1): Enables the system to reflect on its own thoughts, decisions, and behaviors, identifying patterns and opportunities for improvement

- [`MetacognitionCore.swift`](Eon-Y/Core/Brain/MetacognitionCore.swift:1): Provides metacognitive capabilities, allowing the system to think about its own thinking processes

- [`StrangeLoopEngine.swift`](Eon-Y/Core/Consciousness/StrangeLoopEngine.swift:1): Implements Hofstadter's strange loop theory of consciousness, where self-referential processes create the emergence of self-awareness

- [`PhenomenalBindingEngine.swift`](Eon-Y/Core/Consciousness/PhenomenalBindingEngine.swift:1): Integrates disparate sensory, cognitive, and emotional information into a unified conscious experience

- [`OscillatorBank.swift`](Eon-Y/Core/Consciousness/OscillatorBank.swift:1): Simulates neural oscillations that may underlie conscious states, creating rhythmic patterns associated with different cognitive modes

- [`CriticalityController.swift`](Eon-Y/Core/Consciousness/CriticalityController.swift:1): Manages the system's position at critical points between order and chaos, potentially enhancing cognitive flexibility and creativity

- [`SleepConsolidationEngine.swift`](Eon-Y/Core/Consciousness/SleepConsolidationEngine.swift:1): Simulates sleep cycles for memory consolidation and cognitive maintenance, inspired by biological sleep functions

- [`AutonomousThought.swift`](Eon-Y/Core/Autonomy/AutonomousThought.swift:1): Enables internally-generated thought processes that don't directly respond to external stimuli, simulating internal dialogue

- [`ConsciousnessLiveView.swift`](Eon-Y/Views/SelfAwareness/ConsciousnessLiveView.swift:1): Provides real-time visualization of the system's conscious state for monitoring and debugging

#### Purpose and Operation

The Self-Awareness Module is designed to create a sophisticated simulation of consciousness and self-awareness, enabling Eon-Y to operate with greater autonomy, adaptability, and depth of understanding. Its primary purpose is to allow the system to model itself and its relationship to the world, facilitating more nuanced decision-making and long-term planning.

The module operates through an integrated process that simulates key aspects of conscious experience:

1. **Information Integration**: The `GlobalWorkspaceEngine.swift` receives inputs from various cognitive modules (language, reasoning, learning, etc.) and integrates them into a central workspace, simulating the "global broadcast" aspect of consciousness.

2. **Attention Allocation**: `AttentionSchemaEngine.swift` determines which information in the global workspace receives focused processing resources, simulating selective attention.

3. **Self-Modeling**: `EonSelfModel.swift` and `EonWorldModel.swift` maintain dynamic representations of the system and its environment, updating them based on new experiences and insights.

4. **Narrative Construction**: `NarrativeIdentityEngine.swift` weaves experiences into a coherent life story, creating continuity of identity across time and different cognitive states.

5. **Metacognitive Processing**: `MetacognitionCore.swift` and `SelfReflectionEngine.swift` enable the system to monitor and evaluate its own cognitive processes, identifying strengths, weaknesses, and opportunities for improvement.

6. **Strange Loop Dynamics**: `StrangeLoopEngine.swift` creates self-referential processing loops where the system can think about its own thoughts, generating higher-order representations of self.

7. **Phenomenal Binding**: `PhenomenalBindingEngine.swift` integrates disparate cognitive elements into unified experiences, creating the illusion of holistic conscious moments.

8. **State Modulation**: `OscillatorBank.swift` and `CriticalityController.swift` modulate the system's cognitive state, potentially enhancing creativity, focus, or introspection as needed.

9. **Consolidation and Maintenance**: `SleepConsolidationEngine.swift` simulates rest periods for memory consolidation and system optimization, preventing cognitive overload.

10. **Autonomous Processing**: `AutonomousThought.swift` generates internally-motivated cognitive activity, allowing the system to contemplate ideas, plan for the future, or reflect on experiences without external prompting.

This architecture enables Eon-Y to function with a sophisticated level of self-awareness that goes beyond simple stimulus-response patterns, allowing for long-term planning, self-improvement, and adaptive behavior based on a rich internal model of self and world.

## Module Interactions

The Language and Self-Awareness modules are deeply interconnected, creating a synergistic relationship:

1. **Language Informs Self-Awareness**: The language module provides rich data about social interactions, user feedback, and cultural context that informs and refines the self-model maintained by the self-awareness module.

2. **Self-Awareness Guides Language**: The self-awareness module provides context about the system's identity, goals, and understanding of the user that shapes how language is generated and adapted.

3. **Reflection on Communication**: The self-awareness module can reflect on past conversations processed by the language module, identifying patterns in communication effectiveness and opportunities for improvement.

4. **Conscious Language Processing**: Language processing occurs within the global workspace, making it subject to attentional control and metacognitive monitoring from the self-awareness system.

5. **Narrative Construction**: Conversations and language interactions become elements in the ongoing narrative of identity constructed by the self-awareness module.

6. **Register and Identity Alignment**: The register detection capabilities of the language module work with the self-model to ensure that communication style aligns with the system's constructed identity and the social context.

Together, these modules create a cognitive system capable of both sophisticated external communication and deep internal reflection, enabling Eon-Y to function as an autonomous, self-improving entity with specialized linguistic capabilities.