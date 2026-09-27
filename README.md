# Extinction

**Extinction** to modyfikacja dla **Project Zomboid Build 42.20+**, która symuluje stopniowe, całkowite wymarcie zombie. Epidemia nie trwa wiecznie: każde zwykłe zombie otrzymuje własny, wcześniej wyznaczony termin śmierci, a świat z czasem zmienia się z miejsca opanowanego przez żywych zarażonych w niemal pusty krajobraz pełen zwłok i szkieletów.

Mod został zaprojektowany do rozpoczęcia **nowego świata** i jest zgodny z **Project A-Life [ALIFE NPCS]**.

## Najważniejsze cechy

- Stopniowe wymieranie całej zwykłej populacji zombie.
- Konfigurowalny czas do całkowitego wymarcia, domyślnie **21 dni**.
- Jedna trwała, losowa data śmierci dla każdego zombie.
- Historyczne daty śmierci dla zombie odkrywanych po wygaśnięciu epidemii.
- Cicha zamiana zombie w zwłoki, bez walki, odgłosów i punktów zabójstwa.
- Trwałe zwłoki — gra nie usuwa ich automatycznie.
- Konfigurowalna szkieletyzacja, domyślnie po **180 dniach od śmierci**.
- Natywne, lekkie szkielety Project Zomboid zamiast szczegółowych starych ciał.
- Ochrona wszystkich postaci Project A-Life.
- Obsługa zwykłych zombie tworzonych przez inne mody.
- Polskie i angielskie opisy ustawień.

## Jak działa wymieranie zombie

Po utworzeniu świata każde zwykłe zombie dostaje jedną losową godzinę śmierci. Termin jest wybierany równomiernie pomiędzy początkiem świata a końcem okresu ustawionego przez gracza.

Przykład dla ustawienia **21 dni**:

- część zombie umrze w pierwszych dniach,
- część przetrwa około tygodnia lub dwóch,
- ostatnie zombie umrą najpóźniej do końca 21. dnia,
- po tym terminie nie pozostaną żadne żywe zwykłe zombie.

Wylosowany termin jest zapisywany w danych zombie i nie zmienia się zależnie od położenia ani widoczności gracza. Jeżeli termin nadejdzie, gdy zombie znajduje się akurat na ekranie, gracz może zobaczyć jego natychmiastową zmianę w ciało. Widoczność nigdy nie wywołuje śmierci i nie powoduje ponownego losowania terminu.

## Nowo odkrywane rejony

Project Zomboid tworzy część populacji dopiero podczas wczytywania kolejnych obszarów mapy. Extinction obsługuje to bez tworzenia „świeżych” zwłok wiele miesięcy po epidemii:

1. Nowo utworzone zombie otrzymuje termin z pierwotnego okresu epidemii.
2. Jeżeli termin jeszcze nie nadszedł, zombie pozostaje żywe do swojej daty śmierci.
3. Jeżeli termin już minął, zombie natychmiast staje się zwłokami.
4. Ciało otrzymuje wylosowaną historyczną datę śmierci, a nie datę odkrycia przez gracza.
5. Jeżeli od tej historycznej daty minął również czas szkieletyzacji, ciało zostanie zastąpione szkieletem.

Dzięki temu obszar odkryty późno wygląda tak, jakby jego mieszkańcy zginęli podczas tej samej początkowej katastrofy.

## Cicha śmierć

Mod nie zabija zombie przy użyciu ataku ani standardowego systemu walki. Korzysta bezpośrednio z natywnej metody tworzenia zwłok silnika gry. W rezultacie:

- nie jest odtwarzany dźwięk walki,
- nie występuje atak ani obrażenia zadane przez gracza,
- gracz nie dostaje punktów ani zaliczonego zabójstwa,
- nie jest przypisywany sprawca śmierci,
- nie jest wymagana animacja przewrócenia się,
- ciało pojawia się w dokładnym miejscu zombie.

## Szkieletyzacja

Każde ciało zwykłego zombie jest śledzone do chwili osiągnięcia ustawionego wieku. Domyślna wartość to **180 dni od indywidualnej daty śmierci**.

Po osiągnięciu tego wieku:

- szczegółowe ciało zostaje zastąpione natywnym szkieletem Project Zomboid,
- usuwane są ubrania, ekwipunek i indywidualny wygląd ciała,
- zachowane zostają położenie oraz data śmierci,
- szkielet pozostaje w świecie na stałe,
- gotowy szkielet nie jest dalej aktywnie przetwarzany przez mod.

Jest to świadomy kompromis pomiędzy trwałością świata a wydajnością. Setki szczegółowych ciał mogą być kosztowne dla gry, natomiast uproszczone szkielety pozostawiają widoczny ślad katastrofy przy znacznie mniejszym koszcie.

Ustawienie szkieletyzacji na **0** wyłącza automatyczną zamianę. Pełne ciała pozostaną wtedy bezterminowo.

## Trwałość zwłok, odradzanie i choroby

Extinction wymusza następujące ustawienia świata:

- `HoursForCorpseRemoval = 0` — automatyczne usuwanie zwłok jest wyłączone,
- `RespawnHours = 0` — odradzanie zombie jest wyłączone,
- `DecayingCorpseHealthImpact = 4` — wpływ rozkładających się ciał jest ustawiony na **Wysoki**.

Wyłączenie odradzania jest konieczne, ponieważ inaczej gra stale tworzyłaby po wymarciu kolejne zombie, a mod zamieniałby je w nieskończoną liczbę nowych ciał. Naturalne tworzenie początkowej populacji podczas odkrywania mapy nadal działa.

Duże skupiska zwłok mogą być niebezpieczne dla zdrowia postaci. Ochrona dróg oddechowych dostępna w Build 42 może zmniejszać ryzyko zależnie od wyposażenia i stanu filtra.

## Zgodność z Project A-Life

Project A-Life wykorzystuje obiekty klasy zombie jako techniczne „powłoki” swoich ludzkich NPC. Extinction rozpoznaje je przez oficjalne znaczniki:

- `ProjectALifeOwned`,
- `ProjectALifeActor`,
- `ALifeActor`,
- `ALifeUID`.

Obiekt z którymkolwiek z tych oznaczeń jest całkowicie pomijany:

- nie dostaje terminu wymarcia,
- nie jest zamieniany w ciało,
- jego ciało nie jest automatycznie szkieletyzowane przez Extinction,
- może dalej żyć i działać zgodnie z mechaniką Project A-Life.

Zwykłe, nieoznaczone zombie — także utworzone przez Project A-Life lub inny mod — podlegają normalnemu procesowi wymierania. Project A-Life nie jest wymagany; Extinction działa również samodzielnie.

## Ustawienia świata

Po włączeniu moda w opcjach piaskownicy pojawi się strona **Extinction**.

### Dni do całkowitego wymarcia zombie

- Domyślnie: `21`
- Minimum: `0`
- Maksimum: `3650`
- `0` oznacza natychmiastowe wymarcie zwykłych zombie.

Cały rozkład śmierci automatycznie skaluje się do wpisanej wartości.

### Dni od śmierci do szkieletyzacji

- Domyślnie: `180`
- Minimum: `0`
- Maksimum: `3650`
- `0` wyłącza automatyczną szkieletyzację.

Wartość jest liczona osobno od rzeczywistej lub historycznej daty śmierci każdego ciała.

## Instalacja lokalna

Katalog `Extinction` należy umieścić w:

```text
C:\Users\<nazwa użytkownika>\Zomboid\mods\Extinction
```

Następnie należy włączyć mod **Extinction** podczas tworzenia nowego świata. Jeśli używany jest Project A-Life, oba mody powinny być aktywne w tym samym zapisie.

## Wersja i zakres testów

- Docelowa wersja gry: **Project Zomboid Build 42.20+**.
- Wersja moda: **1.0.0**.
- Składnia została sprawdzona parserem Kahlua dołączonym do lokalnej instalacji gry.
- Użyte zdarzenia i metody zostały zweryfikowane bezpośrednio w lokalnym `projectzomboid.jar`.
- Pliki ustawień i tłumaczeń zostały sprawdzone statycznie.
- Zgodność znaczników została sprawdzona z Project A-Life 1.3.0 dla Build 42.20.

Pełny test działającego świata w grze jest osobnym etapem. Mod został przygotowany dla nowego zapisu, ponieważ istniejący świat mógł już wygenerować populację i zwłoki według innych zasad.

## Struktura projektu

```text
mods/Extinction/42.20/
├── mod.info
└── media/
    ├── sandbox-options.txt
    └── lua/
        ├── server/Extinction/ExtinctionServer.lua
        └── shared/Translate/
            ├── EN/Sandbox.json
            └── PL/Sandbox.json
```

## Prywatność i publikacja

Projekt jest przeznaczony do prywatnego repozytorium GitHub i prywatnej pozycji Steam Workshop. Kod nie zawiera danych logowania, tokenów, zapisów świata ani danych osobowych.
