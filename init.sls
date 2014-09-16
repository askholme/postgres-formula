{% from "postgres/map.jinja" import postgres with context %}

python-apt:
  pkg.installed

postgresql:
  pkgrepo.managed:
    - humanname: postgresql
    - name: deb http://apt.postgresql.org/pub/repos/apt/ sid-pgdg main
    - key_url: https://www.postgresql.org/media/keys/ACCC4CF8.asc
    - file: /etc/apt/sources.list.d/pgdg.list
    - require:
      - pkg: python-apt
    - require_in:
      - pkg: {{ postgres.pkg }}
      - pkg: postgresql-contrib-9.3
  pkg.installed:
    - name: {{ postgres.pkg }}
  file.managed:
    - name: /etc/service/postgres/run
    - source: salt://postgres/postgres-run
    - mode: 755
    - makedirs: true
    - require:
      - pkg: {{ postgres.pkg }}
      
      
postgres_firstrun:
  file.managed:
    - name: /etc/init.d/postgres
    - source: salt://postgres/postgres-firstrun
    - mode: 755
    - makedirs: true
postgres_firstrun_finish:    
  file.managed:
    - name: /service/postgres_firstrun/finish
    - source: salt://postgre/postgres-firstrun-finish
    - mode: 755
    - makedirs: true

postgresql-contrib-9.3:
  pkg.installed
postgresql-server-dev-9.3:
  pkg.installed
  
libpq-dev:
  pkg.installed

python-dev:
  pkg.installed

{% if 'pg_hba.conf' in pillar.get('postgres', {}) %}
pg_hba.conf:
  file.managed:
    - name: {{ postgres.pg_hba }}
    - source: {{ salt['pillar.get']('postgres:pg_hba.conf', 'salt://postgres/pg_hba.conf') }}
    - template: jinja
    - user: postgres
    - group: postgres
    - mode: 644
    - require:
      - pkg: {{ postgres.pkg }}
    - watch_in:
      - cmd: postgres_service
{% endif %}

{% if 'users' in pillar.get('postgres', {}) %}
{% for name, user in salt['pillar.get']('postgres:users').items()  %}
postgres-user-{{ name }}:
  postgres_user.present:
    - name: {{ name }}
    - createdb: {{ salt['pillar.get']('postgres:users:' + name + ':createdb', False) }}
    - password: {{ salt['pillar.get']('postgres:users:' + name + ':password', 'changethis') }}
    - runas: postgres
    - require:
      - cmd: postgres_service
{% endfor%}
{% endif %}

{% if 'databases' in pillar.get('postgres', {}) %}
{% for name, db in salt['pillar.get']('postgres:databases').items()  %}
postgres-db-{{ name }}:
  postgres_database.present:
    - name: {{ name }}
    - encoding: {{ salt['pillar.get']('postgres:databases:'+ name +':encoding', 'UTF8') }}
    - lc_ctype: {{ salt['pillar.get']('postgres:databases:'+ name +':lc_ctype', 'en_US.UTF8') }}
    - lc_collate: {{ salt['pillar.get']('postgres:databases:'+ name +':lc_collate', 'en_US.UTF8') }}
    - template: {{ salt['pillar.get']('postgres:databases:'+ name +':template', 'template0') }}
    {% if salt['pillar.get']('postgres:databases:'+ name +':owner') %}
    - owner: {{ salt['pillar.get']('postgres:databases:'+ name +':owner') }}
    {% endif %}
    - runas: {{ salt['pillar.get']('postgres:databases:'+ name +':runas', 'postgres') }}
    {% if salt['pillar.get']('postgres:databases:'+ name +':user') %}
    - require:
        - postgres_user: postgres-user-{{ salt['pillar.get']('postgres:databases:'+ name +':user') }}
    {% endif %}
{% endfor%}
{% endif %}
{% if 'extensions' in pillar.get('postgres', {}) %}
{% for ext in salt['pillar.get']('postgres:extensions') %}
postgres-extension-{{ ext['name']}}:
  postgres_extension.present:
    - name: {{  ext['name'] }}
    - maintenance_db: {{  ext['db_name'] }}
    - require:
      - postgres_database: postgres-db-{{ ext['db_name'] }}
{% endfor %}
{% endif %}