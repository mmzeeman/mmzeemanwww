{% if id.o.author %}
<span class="text-muted">{_ By: _}</span>
{% include "_content_list.tpl" list=id.o.author %}
{% endif %}
