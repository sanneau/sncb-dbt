{% macro hash_key(columns) %}
    md5(
        concat_ws(
            '||',
            {% for c in columns %}
                upper(trim(cast({{ c }} as varchar)))
                {% if not loop.last %}, {% endif %}
            {% endfor %}
        )
    )
{% endmacro %}
