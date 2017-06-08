{% from "docker/map.jinja" import containers with context %}

include:
  - docker

{% for name, container in containers.items() %}
docker-image-{{ name }}:
  cmd.run:
    - name: docker pull {{ container.image }}
    - require:
      - service: docker-service

{# TODO: SysV init script #}
{%- set init_system = salt["cmd.run"]("ps -p1 | grep -q systemd && echo systemd || echo upstart") %}

docker-container-startup-config-{{ name }}:
  file.managed:
{%- if init_system == "systemd" %}
    - name: /etc/systemd/system/docker-{{ name }}.service
    - source: salt://docker/files/systemd.conf
{%- elif init_system == "upstart" %}
    - name: /etc/init/docker-{{ name }}.conf
    - source: salt://docker/files/upstart.conf
{%- endif %}
    - mode: 700
    - user: root
    - template: jinja
    - defaults:
        name: {{ name | json }}
        container: {{ container | json }}
    - require:
      - cmd: docker-image-{{ name }}

{%- if init_system == "systemd" %}
daemon-reload-{{ name }}:
  cmd.run:
    - name: systemctl daemon-reload
    - watch:
      - file: docker-container-startup-config-{{ name }}
{%- endif %}

{%- if init_system == "systemd" %}
daemon-restart-{{ name }}:
  cmd.run:
    - name: service docker-{{ name }} restart
    - watch:
      - cmd: daemon-reload-{{ name }}
{%- endif %}

docker-container-service-{{ name }}:
  service.running:
    - name: docker-{{ name }}
    - enable: True
    - watch:
      - file: docker-container-startup-config-{{ name }}
{%- if init_system == "systemd" %}
    - require:
      - cmd: daemon-reload-{{ name }}
{%- endif %}
{% endfor %}
