"use client";

import { useState, useCallback } from "react";
import { useQuery } from "@tanstack/react-query";
import { createClient } from "@/lib/supabase/client";
import { generateReport } from "@/features/reports/actions/generate-report";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { FileText, Download, Loader2, FileDown, FileJson } from "lucide-react";

type Unidade = { id: string; nome: string };

const formatMap: Record<string, string> = {
  csv: "CSV",
  json: "JSON",
  pdf: "PDF",
  xlsx: "XLSX",
};

const statusMap: Record<string, string> = {
  pending: "Pendente",
  generating: "Gerando",
  completed: "Concluído",
  failed: "Falha",
};

export function ReportsContent() {
  const [formato, setFormato] = useState("csv");
  const [dataInicio, setDataInicio] = useState("");
  const [dataFim, setDataFim] = useState("");
  const [unidadeId, setUnidadeId] = useState("");
  const [generating, setGenerating] = useState(false);
  const supabase = createClient();

  const { data: historico } = useQuery({
    queryKey: ["reports-history"],
    queryFn: async () => {
      const { data } = await supabase
        .from("relatorios_gerados")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(20);
      return data ?? [];
    },
  });

  const { data: unidades } = useQuery({
    queryKey: ["unidades"],
    queryFn: async () => {
      const { data } = await supabase
        .from("unidades")
        .select("id, nome")
        .is("deleted_at", null);
      return data as Unidade[];
    },
  });

  const handleGenerate = useCallback(async () => {
    setGenerating(true);
    try {
      const form = new FormData();
      form.set("formato", formato);
      form.set("dataInicio", dataInicio);
      form.set("dataFim", dataFim);
      form.set("unidadeId", unidadeId);

      const result = await generateReport(form);

      if ("error" in result) {
        console.error(result.error);
        return;
      }

      const content = result.csv ?? result.json ?? "";
      const type = formato === "csv"
        ? "text/csv;charset=utf-8;"
        : "application/json;charset=utf-8;";
      const blob = new Blob([content], { type });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = result.filename;
      a.click();
      URL.revokeObjectURL(url);
    } finally {
      setGenerating(false);
    }
  }, [formato, dataInicio, dataFim, unidadeId]);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Relatórios</h1>
        <p className="text-muted-foreground">Gere e baixe relatórios de avaliações</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Gerar Novo Relatório</CardTitle>
          <CardDescription>Selecione os filtros e o formato desejado</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-5">
            <div className="space-y-2">
              <Label htmlFor="formato">Formato</Label>
              <Select value={formato} onValueChange={(v) => v && setFormato(v)}>
                <SelectTrigger id="formato">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="csv">CSV</SelectItem>
                  <SelectItem value="json">JSON</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="dataInicio">Data Início</Label>
              <Input id="dataInicio" type="date" value={dataInicio} onChange={(e) => setDataInicio(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="dataFim">Data Fim</Label>
              <Input id="dataFim" type="date" value={dataFim} onChange={(e) => setDataFim(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="unidade">Unidade</Label>
              <Select value={unidadeId} onValueChange={(v) => setUnidadeId(v ?? "")}>
                <SelectTrigger id="unidade">
                  <SelectValue placeholder="Todas" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">Todas</SelectItem>
                  {(unidades ?? []).map((u) => (
                    <SelectItem key={u.id} value={u.id}>{u.nome}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-end">
              <Button onClick={handleGenerate} disabled={generating} className="w-full gap-2">
                {generating ? <Loader2 className="h-4 w-4 animate-spin" /> : <FileDown className="h-4 w-4" />}
                {generating ? "Gerando..." : "Gerar"}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Histórico de Relatórios</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Formato</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Data</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {(historico ?? []).length === 0 && (
                <TableRow>
                  <TableCell colSpan={3} className="text-center text-muted-foreground py-8">
                    Nenhum relatório gerado ainda
                  </TableCell>
                </TableRow>
              )}
              {(historico ?? []).map((r) => (
                <TableRow key={r.id}>
                  <TableCell>
                    <Badge variant="outline" className="gap-1">
                      {r.formato === "csv" ? <FileText className="h-3 w-3" /> : <FileJson className="h-3 w-3" />}
                      {formatMap[r.formato] ?? r.formato}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <Badge variant={r.status === "completed" ? "default" : r.status === "failed" ? "destructive" : "secondary"}>
                      {statusMap[r.status] ?? r.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {new Date(r.created_at).toLocaleString("pt-BR")}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
