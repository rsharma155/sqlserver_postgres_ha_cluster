import resource_advisor


def test_recommend_returns_valid_shape():
    r = resource_advisor.recommend()
    assert isinstance(r, dict)
    assert "total_ram_gb" in r
    assert "scale" in r
    assert 0.15 <= r["scale"] <= 1.0


def test_memory_values_have_correct_suffixes():
    r = resource_advisor.recommend()
    for key in ("pg_patroni_mem", "pg_etcd_mem", "pg_haproxy_mem", "pg_backup_mem", "pg_seaweed_mem"):
        val = r[key]
        assert val.endswith("g") or val.endswith("m"), f"{key}={val} should end with g or m"
    for key in ("sql_node_mem", "sql_node3_mem"):
        val = r[key]
        assert val.endswith("g"), f"{key}={val} should end with g"
    for key in ("pg_shared_buffers", "pg_effective_cache_size"):
        val = r[key]
        assert val.endswith("MB"), f"{key}={val} should end with MB"


def test_scale_tiers_produce_different_values():
    original_fn = resource_advisor.get_total_ram_gb
    results = {}
    for ram, label in [(40, "high"), (24, "mid"), (12, "low"), (4, "min")]:
        resource_advisor.get_total_ram_gb = lambda r=ram: r
        r = resource_advisor.recommend()
        results[label] = r["pg_patroni_mem"]
    resource_advisor.get_total_ram_gb = original_fn
    assert results["high"] != results["min"], "Scale should produce different memory limits"


def test_minimum_limits():
    r = resource_advisor.recommend()
    pg_val = r["pg_patroni_mem"]
    sql_val = r["sql_node_mem"]
    assert float(pg_val.rstrip("gm")) >= 0.5
    assert float(sql_val.rstrip("g")) >= 1
