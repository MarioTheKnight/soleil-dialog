# Soleil Dialog Module

Un systeme de dialogues RPG complet pour Godot 4 : portraits, choix du joueur, animation de texte (typewriter), effets RichText personnalises, et mode auto-read configurable.

---

## Architecture

Le module separe les **donnees** (resources editables dans l'inspecteur) du **flux** (le manager qui enchaine les lignes et gere l'input).

```mermaid
graph TD
    subgraph Resources Vos Assets
        DS[DialogSequence .tres]
        DL[DialogLine .tres]
        DC[DialogChoice .tres]
    end

    subgraph DialogManager Autoload
        DM[Singleton Global]
        Timer[Auto-Read Timer]
    end

    subgraph UI
        DB[DialogBox CanvasLayer 90]
        Effects[RichTextBounce / RichTextDrop]
    end

    subgraph Integration Optionnelle
        OM[OptionsManager]
    end

    DS -->|contient| DL
    DS -->|contient| DC
    DM -->|instancie| DB
    DM -->|lit| DS
    DB -->|affiche| DL
    DB -->|affiche| DC
    DB -->|installe| Effects
    OM -.->|text_speed, auto_read| DM

    style DM fill:#154a87,stroke:#333,color:#fff
    style DB fill:#2a3a4a,stroke:#333,color:#fff
    style DS fill:#875615,stroke:#333,color:#fff
```

---

## Installation (Git Submodule)

```bash
git submodule add https://github.com/MarioTheKnight/soleil-dialog.git addons/soleil_dialog
```

Puis dans Godot : **Projet > Parametres du projet > Plugins** > cocher **Soleil Dialog**.
L'autoload `DialogManager` est enregistre automatiquement.

---

## Utilisation depuis l'Editeur (Creer un dialogue)

### 1. Creer les lignes de dialogue

1. Clic droit dans votre dossier `assets/` > **Creer un nouveau... > Ressource**
2. Choisissez le type **`DialogLine`**
3. Dans l'inspecteur, remplissez :
   - `character_name` : cle de traduction du nom (ex: `CHAR_HERO`)
   - `text` : cle de traduction du texte (ex: `DLG_GREETING_01`)
   - `portrait` : glissez une texture de portrait
   - `typing_style` : `"typewriter"` (par defaut) ou `"instant"`
   - `portrait_side` : `"left"` ou `"right"`
4. Repetez pour chaque replique

### 2. Creer la sequence

1. Creez une ressource **`DialogSequence`**
2. Glissez vos `DialogLine` dans le tableau `lines` (dans l'ordre)
3. Optionnel : ajoutez des `DialogChoice` dans le tableau `choices` (affiches apres la derniere ligne)
4. Donnez un `id` unique (utile pour le branchement)

### 3. Lancer le dialogue en code

```gdscript
@export var greeting_dialog: DialogSequence

func _on_player_interact() -> void:
    DialogManager.play_dialog(greeting_dialog)
```

---

## Utilisation Programatique (GDScript)

### Lancer un dialogue

```gdscript
# Le Game Designer glisse la resource dans l'inspecteur
@export var my_dialog: DialogSequence

func start_conversation() -> void:
    DialogManager.play_dialog(my_dialog)
```

### Ecouter le debut et la fin

```gdscript
func _ready() -> void:
    DialogManager.dialog_started.connect(_on_dialog_started)
    DialogManager.dialog_finished.connect(_on_dialog_finished)

func _on_dialog_started(sequence_id: String) -> void:
    # Desactiver les controles du joueur
    set_physics_process(false)

func _on_dialog_finished(sequence_id: String) -> void:
    # Reactiver les controles
    set_physics_process(true)
```

### Controles du joueur pendant le dialogue

| Action | Effet |
|--------|-------|
| `ui_accept` (Entree/Espace) | Avance a la ligne suivante, ou skip le typing en cours |
| `ui_cancel` (Echap) | Ferme le dialogue (si `can_skip = true` sur la sequence) |

### Effets RichText dans le texte

Le module installe deux effets BBCode personnalises utilisables dans les traductions :

```
# Dans votre fichier CSV de traduction :
DLG_GREETING_01,en,"[bounce freq=5.0 height=4.0]Hello![/bounce] How are you?"
DLG_EARTHQUAKE,en,"The ground [drop delay=0.05 height=20.0]is shaking![/drop]"
```

---

## Resources (Reference)

### DialogSequence

| Propriete | Type | Defaut | Description |
|-----------|------|--------|-------------|
| `id` | `String` | `""` | Identifiant unique de la sequence (pour le branchement) |
| `lines` | `Array[DialogLine]` | `[]` | Lignes de dialogue dans l'ordre |
| `choices` | `Array[DialogChoice]` | `[]` | Choix affiches apres la derniere ligne |
| `can_skip` | `bool` | `true` | Autoriser Echap a fermer le dialogue |
| `card_phase_before_choices` | `bool` | `false` | Emet `card_play_phase_started` et attend `resolve_card_play_phase()` avant d'afficher les choix |

### DialogLine

| Propriete | Type | Defaut | Description |
|-----------|------|--------|-------------|
| `character_name` | `String` | `""` | Cle i18n du nom du personnage |
| `text` | `String` | `""` | Cle i18n du texte (supporte les effets BBCode) |
| `portrait` | `Texture2D` | `null` | Portrait du personnage |
| `typing_style` | `"typewriter"` / `"instant"` | `"typewriter"` | Mode d'apparition du texte |
| `speed_multiplier` | `float` (0.1 - 5.0) | `1.0` | Multiplicateur de vitesse relatif au reglage global |
| `custom_voice_blip` | `AudioStream` | `null` | Son de frappe personnalise |
| `portrait_side` | `"left"` / `"right"` | `"left"` | Cote du portrait a l'ecran |

### DialogChoice

| Propriete | Type | Defaut | Description |
|-----------|------|--------|-------------|
| `text` | `String` | `""` | Cle i18n du texte du choix |
| `target_dialog_id` | `String` | `""` | ID de la sequence cible (branchement, via le catalogue) |
| `ends_conversation` | `bool` | `false` | Si `true`, ferme le dialogue sans brancher |
| `preconditions` | `Array[DialogCondition]` | `[]` | Conditions (toutes requises) pour que le choix soit selectionnable |
| `hide_when_locked` | `bool` | `false` | `true` : choix verrouille masque ; `false` : affiche grise |
| `locked_hint_key` | `String` | `""` | Cle i18n ajoutee au choix grise (ex: "requiert 15 intimidation") |

---

## Variables de dialogue et preconditions

`DialogManager.dialog_vars` est une table `Dictionary[StringName, Variant]` **locale au dialogue en cours** (videe au debut et a la fin de chaque dialogue). Le gameplay y ecrit, les preconditions y lisent :

```gdscript
DialogManager.set_dialog_var(&"intimidation", 15)   # ex: effet d'une carte sociale
var value: Variant = DialogManager.get_dialog_var(&"intimidation", 0)
```

Les preconditions sont des ressources **`DialogCondition`** composables, assignees dans l'inspecteur sur `DialogChoice.preconditions` :

| Condition | Passe quand |
|-----------|-------------|
| `VarAtLeastCondition` | `vars[var_name] >= min_value` (absente = 0) |
| `VarEqualsCondition` | `vars[var_name] == expected_value` |
| `VarTruthyCondition` | la variable est presente et vraie (flag) |
| `AllOfCondition` | toutes les conditions imbriquees passent (ET) |
| `AnyOfCondition` | au moins une condition imbriquee passe (OU) |
| `NotCondition` | la condition imbriquee echoue (NON) |

Pour un besoin specifique, sous-classez `DialogCondition` dans votre jeu et implementez `evaluate(vars) -> bool`.

## Branchement par catalogue

Pour qu'un `DialogChoice.target_dialog_id` fonctionne, la sequence cible doit etre **enregistree** :

```gdscript
DialogManager.register_sequence(branch_sequence)      # ou register_sequences([...])
DialogManager.play_dialog(intro_sequence)
# Un choix avec target_dialog_id = branch_sequence.id enchaine dans la meme boite,
# en conservant dialog_vars. clear_sequence_catalog() vide le catalogue.
```

## Hook mini-jeu (phase de cartes)

Si `DialogSequence.card_phase_before_choices` est `true`, au moment d'afficher les choix le manager emet `card_play_phase_started(sequence_id)` et attend. Le jeu affiche alors sa propre UI (ex: une main de cartes sociales), ecrit dans `dialog_vars`, puis rend la main :

```gdscript
DialogManager.card_play_phase_started.connect(func(_id: String) -> void:
    my_social_hand.open()   # les effets de cartes ecrivent dans dialog_vars
)
# Quand le joueur a fini :
DialogManager.resolve_card_play_phase()   # re-filtre et affiche les choix
```

---

## Effets RichText

### `[bounce]` (RichTextBounce)

Fait rebondir les caracteres individuellement. Ideal pour les exclamations ou les emotions fortes.

```
[bounce freq=5.0 height=4.0]Texte qui rebondit ![/bounce]
```

| Parametre | Type | Defaut | Description |
|-----------|------|--------|-------------|
| `freq` | `float` | `5.0` | Frequence du rebond |
| `height` | `float` | `4.0` | Hauteur du rebond en pixels |

### `[drop]` (RichTextDrop)

Les caracteres tombent un par un depuis le haut, creant un effet de revelation dramatique.

```
[drop delay=0.05 height=20.0]Texte qui tombe ![/drop]
```

| Parametre | Type | Defaut | Description |
|-----------|------|--------|-------------|
| `delay` | `float` | `0.05` | Delai entre chaque caractere (secondes) |
| `height` | `float` | `20.0` | Hauteur de chute en pixels |

---

## Signaux

| Signal | Parametres | Description |
|--------|------------|-------------|
| `dialog_started` | `sequence_id: String` | Emis au debut d'une sequence |
| `dialog_finished` | `sequence_id: String` | Emis a la fin (derniere ligne lue ou dialogue skip) |
| `card_play_phase_started` | `sequence_id: String` | La sequence attend le mini-jeu du jeu hote (voir hook ci-dessus) |
| `card_play_phase_resolved` | `sequence_id: String` | `resolve_card_play_phase()` appele, les choix vont s'afficher |

### Signaux de la DialogBox (internes)

| Signal | Parametres | Description |
|--------|------------|-------------|
| `line_finished` | aucun | Le typing de la ligne courante est termine |
| `choice_selected` | `target_id: String, ends_conversation: bool` | Le joueur a clique un choix |

---

## Integration avec OptionsManager

Si `soleil_options` est installe, `DialogManager` enregistre **automatiquement** un onglet "Dialog" dans le menu d'options avec 3 reglages :

| Option | Section | Cle | Defaut | Plage |
|--------|---------|-----|--------|-------|
| Vitesse du texte | `dialog` | `text_speed` | `1.0` | 0.1 - 3.0 |
| Auto-read active | `dialog` | `auto_read` | `false` | on/off |
| Vitesse auto-read | `dialog` | `auto_read_speed` | `1.0` | 0.5 - 3.0 |

Les cles de traduction pour l'UI de l'onglet :

| Cle i18n | Usage |
|----------|-------|
| `TEXT_SPEED` | Label du slider de vitesse |
| `AUTO_READ_ENABLE` | Label du toggle auto-read |
| `AUTO_READ_DELAY` | Label du slider de delai |
| `DIALOG_OPTIONS` | Titre de l'onglet |

---

## Dependances

| Module | Requis ? | Integration |
|--------|----------|-------------|
| `soleil_core` | non | Utilise `TranslationServer` directement (compatible avec ou sans Soleil) |
| `soleil_options` | non | Si present : enregistre un onglet Dialog dans le menu d'options |

---

## Structure du module

```text
addons/soleil_dialog/
  plugin.cfg
  soleil_dialog.gd              # Enregistre l'autoload
  autoloads/
    dialog_manager.gd           # Singleton DialogManager
  resources/
    dialog_sequence.gd          # Resource DialogSequence
    dialog_line.gd              # Resource DialogLine
    dialog_choice.gd            # Resource DialogChoice
    conditions/
      dialog_condition.gd       # Base abstraite des preconditions
      var_at_least_condition.gd # vars[x] >= n
      var_equals_condition.gd   # vars[x] == n
      var_truthy_condition.gd   # flag present et vrai
      all_of_condition.gd       # ET
      any_of_condition.gd       # OU
      not_condition.gd          # NON
  effects/
    rich_text_bounce.gd         # Effet BBCode [bounce]
    rich_text_drop.gd           # Effet BBCode [drop]
  ui/
    dialog_box.tscn             # Scene de la boite de dialogue
    dialog_box.gd               # Script UI (CanvasLayer)
```

---

## Organisation Recommandee

```text
MonJeu/
  addons/
    soleil_dialog/              # Le module (ne pas modifier)
  assets/
    dialogs/
      npc_villager/
        villager_greet.tres     # DialogSequence
        villager_line_01.tres   # DialogLine
        villager_portrait.png
      npc_merchant/
        merchant_shop.tres
  game/
    translations/
      dialogs.csv               # Cles : CHAR_*, DLG_*
```
