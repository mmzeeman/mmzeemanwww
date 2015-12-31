{% extends "base.tpl" %}

{% block title %}{{ m.site.title }}{% endblock %}

{% block main %}

<div class="page-header">
    <h1>{{ m.rsc.page_home.title }} <small>{{ m.rsc.page_home.summary }}</small>
</div>

{{ m.rsc.page_home.body|show_media }}

{% endblock %}

{% block subnavbar %}
{% include "_content_list.tpl" list=m.search[{query cat='article' sort='-rsc.modified' pagelen=5}] title=_"Recent content" %}
{% endblock %}
