"use server";

import { createClient } from "@/lib/supabase/server";

type ReportFormat = "csv" | "json";

export async function generateReport(formData: FormData) {
  const supabase = await createClient();
  const formato = formData.get("formato") as ReportFormat;
  const dataInicio = formData.get("dataInicio") as string;
  const dataFim = formData.get("dataFim") as string;
  const unidadeId = formData.get("unidadeId") as string;

  let query = supabase
    .from("avaliacoes")
    .select("nota, canal, created_at, unidade_id")
    .gte("created_at", dataInicio || "1970-01-01")
    .lte("created_at", dataFim || "2100-01-01")
    .is("deleted_at", null);

  if (unidadeId) {
    query = query.eq("unidade_id", unidadeId);
  }

  const { data, error } = await query.order("created_at", { ascending: false });

  if (error) {
    return { error: error.message };
  }

  const unidades = await supabase.from("unidades").select("id, nome");

  const unidadeMap = new Map(
    (unidades.data ?? []).map((u: { id: string; nome: string }) => [u.id, u.nome])
  );

  const rows = (data ?? []).map((r) => ({
    data: r.created_at,
    nota: r.nota,
    canal: r.canal,
    unidade: unidadeMap.get(r.unidade_id) ?? "N/A",
  }));

  if (formato === "csv") {
    const csv = "data,nota,canal,unidade\n" +
      rows
        .map((r) => `"${r.data}","${r.nota}","${r.canal}","${r.unidade}"`)
        .join("\n");

    const filename = `relatorio-avaliacoes-${Date.now()}.csv`;

    await supabase.from("relatorios_gerados").insert({
      config_id: "00000000-0000-0000-0000-000000000000",
      municipio_id: "00000000-0000-0000-0000-000000000001",
      status: "completed",
      formato: "csv",
      storage_path: filename,
    });

    return { csv, filename };
  }

  const filename = `relatorio-avaliacoes-${Date.now()}.json`;

  await supabase.from("relatorios_gerados").insert({
    config_id: "00000000-0000-0000-0000-000000000000",
    municipio_id: "00000000-0000-0000-0000-000000000001",
    status: "completed",
    formato: "json",
    storage_path: filename,
  });

  return { json: JSON.stringify(rows, null, 2), filename };
}
