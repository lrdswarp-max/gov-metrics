import { createAdminClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Building2, Star, ThumbsUp, TrendingUp } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function TransparencyPage() {
  const supabase = createAdminClient();

  const { count: totalAvaliacoes } = await supabase
    .from("avaliacoes")
    .select("*", { count: "exact", head: true })
    .is("deleted_at", null);

  const { data: distribuicao } = await supabase.rpc("fn_distribuicao_notas");

  const dist = { excellent: 0, good: 0, regular: 0, bad: 0 };
  if (distribuicao) {
    for (const row of distribuicao) {
      dist[row.nota as keyof typeof dist] = Number(row.total);
    }
  }

  const total = totalAvaliacoes ?? 0;
  const satisfacao = total > 0
    ? Math.round(((dist.excellent + dist.good) / total) * 100)
    : 0;

  const { data: unidades } = await supabase
    .from("unidades")
    .select("id, nome, tipo")
    .is("deleted_at", null);

  const { data: ranking } = await supabase.rpc("fn_ranking_unidades");

  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-white">
      <div className="mx-auto max-w-5xl px-4 py-12">
        <div className="mb-10 text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-xl bg-blue-600">
            <Building2 className="h-7 w-7 text-white" />
          </div>
          <h1 className="text-3xl font-bold tracking-tight">Transparência</h1>
          <p className="mt-2 text-muted-foreground">
            Indicadores de satisfação dos serviços públicos — Cidade Exemplo
          </p>
        </div>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Total de Avaliações</CardTitle>
              <Star className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">{total}</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Satisfação Geral</CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-green-600">{satisfacao}%</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Unidades</CardTitle>
              <Building2 className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">{unidades?.length ?? 0}</p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium">Avaliações Positivas</CardTitle>
              <ThumbsUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">{dist.excellent + dist.good}</p>
            </CardContent>
          </Card>
        </div>

        <Card className="mt-8">
          <CardHeader>
            <CardTitle>Ranking de Unidades</CardTitle>
          </CardHeader>
          <CardContent>
            {(ranking ?? []).length === 0 ? (
              <p className="text-center text-muted-foreground py-8">Nenhum dado disponível</p>
            ) : (
              <div className="divide-y">
                {(ranking ?? []).map((r, i) => (
                  <div key={r.unidade_id} className="flex items-center justify-between py-3">
                    <div className="flex items-center gap-3">
                      <span className="flex h-7 w-7 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700">
                        {i + 1}
                      </span>
                      <div>
                        <p className="font-medium">{r.unidade_nome}</p>
                        <Badge variant="outline">{r.tipo}</Badge>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-lg font-bold text-green-600">{r.satisfacao}%</p>
                      <p className="text-xs text-muted-foreground">{r.total} avaliações</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
