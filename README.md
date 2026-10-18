# Geburtstag 13.11.2026

Einladung als Plakatwand mit Anmeldung, Begleitung, Wunschliste, Geschenkgruppen und Gästeideen.
Statische Seite auf GitHub Pages, Daten in Supabase.

## Einrichtung (einmalig)

1. Auf [supabase.com](https://supabase.com) ein kostenloses Projekt anlegen.
2. **SQL Editor** → Inhalt von `supabase/schema.sql` einfügen → *Run*.
3. **Authentication → Sign In / Providers**: *Allow anonymous sign-ins* einschalten. E-Mail-Login bleibt an.
4. **Authentication → URL Configuration**: *Site URL* auf die GitHub-Pages-Adresse setzen
   (z. B. `https://oliviajools.github.io/geburtstag-1311/`) und dieselbe Adresse bei *Redirect URLs* eintragen.
5. **Project Settings → API**: *Project URL* und *anon public key* in `config.js` eintragen, committen, pushen.

## Host werden

1. Seite mit `#host` am Ende öffnen, z. B. `https://oliviajools.github.io/geburtstag-1311/#host`.
2. Eigene E-Mail eintragen, Login-Link aus der Mail auf demselben Gerät öffnen.
3. Im Supabase **SQL Editor** einmal ausführen (eigene Adresse einsetzen):

   ```sql
   insert into public.hosts (user_id) select id from auth.users where email = 'DEINE@MAIL.DE';
   ```

4. Seite neu laden. Jetzt kannst du im Innenteil Wünsche anlegen. Gruppen und Gästeideen sind hinter „Spoiler zeigen“ versteckt.

## Gut zu wissen

- Gäste brauchen kein Konto. Beim ersten Besuch bekommen sie im Browser einen anonymen Login. Wer auf einem anderen Gerät öffnet, ist dort ein neuer Gast.
- Seite, Foto und Gästeliste sind für alle mit dem Link sichtbar.
