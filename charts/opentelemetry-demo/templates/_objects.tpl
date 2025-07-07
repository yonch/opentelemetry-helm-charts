{{/*
Demo component Deployment template
*/}}
{{- define "otel-demo.deployment" }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
  labels:
    {{- include "otel-demo.labels" . | nindent 4 }}
spec:
  replicas: {{ .replicas | default .defaultValues.replicas }}
  revisionHistoryLimit: {{ .revisionHistoryLimit | default .defaultValues.revisionHistoryLimit }}
  selector:
    matchLabels:
      {{- include "otel-demo.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "otel-demo.selectorLabels" . | nindent 8 }}
        {{- include "otel-demo.workloadLabels" . | nindent 8 }}
      {{- if .podAnnotations }}
      annotations:
        {{- toYaml .podAnnotations | nindent 8 }}
      {{- end }}
    spec:
      {{- if or .defaultValues.image.pullSecrets ((.imageOverride).pullSecrets) }}
      imagePullSecrets:
        {{- ((.imageOverride).pullSecrets) | default .defaultValues.image.pullSecrets | toYaml | nindent 8}}
      {{- end }}
      serviceAccountName: {{ include "otel-demo.serviceAccountName" .}}
      {{- $schedulingRules := .schedulingRules | default dict }}
      {{- if or .defaultValues.schedulingRules.nodeSelector $schedulingRules.nodeSelector}}
      nodeSelector:
        {{- $schedulingRules.nodeSelector | default .defaultValues.schedulingRules.nodeSelector | toYaml | nindent 8 }}
      {{- end }}
      {{- if or .defaultValues.schedulingRules.affinity $schedulingRules.affinity}}
      affinity:
        {{- $schedulingRules.affinity | default .defaultValues.schedulingRules.affinity | toYaml | nindent 8 }}
      {{- end }}
      {{- if or .defaultValues.schedulingRules.tolerations $schedulingRules.tolerations}}
      tolerations:
        {{- $schedulingRules.tolerations | default .defaultValues.schedulingRules.tolerations | toYaml | nindent 8 }}
      {{- end }}
      {{- if or .defaultValues.podSecurityContext .podSecurityContext }}
      securityContext:
        {{- .podSecurityContext | default .defaultValues.podSecurityContext | toYaml | nindent 8 }}
      {{- end}}
      containers:
        - name: {{ .name }}
          image: '{{ ((.imageOverride).repository) | default .defaultValues.image.repository }}:{{ ((.imageOverride).tag) | default (printf "%s-%s" (default .Chart.AppVersion .defaultValues.image.tag) .name) }}'
          imagePullPolicy: {{ ((.imageOverride).pullPolicy) | default .defaultValues.image.pullPolicy }}
          {{- if .command }}
          command:
            {{- .command | toYaml | nindent 12 -}}
          {{- end }}
          {{- if or .ports .service}}
          ports:
            {{- include "otel-demo.pod.ports" . | nindent 12 }}
          {{- end }}
          env:
            {{- include "otel-demo.pod.env" . | nindent 12 }}
          resources:
            {{- $mergedResources := dict }}
            {{- if .defaultValues.resources }}
            {{- $mergedResources = .defaultValues.resources | deepCopy }}
            {{- end }}
            {{- if .resources }}
            {{- $mergedResources = mergeOverwrite $mergedResources .resources }}
            {{- end }}
            {{- $mergedResources | toYaml | nindent 12 }}
          {{- if or .defaultValues.securityContext .securityContext }}
          securityContext:
            {{- .securityContext | default .defaultValues.securityContext | toYaml | nindent 12 }}
          {{- end}}
          {{- if .livenessProbe }}
          livenessProbe:
            {{- .livenessProbe | toYaml | nindent 12 }}
          {{- end }}
          volumeMounts:
          {{- range .mountedConfigMaps }}
            - name: {{ .name | lower }}
              mountPath: {{ .mountPath }}
              {{- if .subPath }}
              subPath: {{ .subPath }}
              {{- end }}
          {{- end }}
          {{- range .mountedEmptyDirs }}
            - name: {{ .name | lower }}
              mountPath: {{ .mountPath }}
              {{- if .subPath }}
              subPath: {{ .subPath }}
              {{- end }}
          {{- end }}
        {{- range .sidecarContainers }}
        {{- $sidecar := set . "name" (.name | lower)}}
        {{- $sidecar := set . "Chart" $.Chart }}
        {{- $sidecar := set . "Release" $.Release }}
        {{- $sidecar := set . "defaultValues" $.defaultValues }}
        - name: {{ .name   }}
          image: '{{ ((.imageOverride).repository) | default .defaultValues.image.repository }}:{{ ((.imageOverride).tag) | default (printf "%s-%s" (default .Chart.AppVersion .defaultValues.image.tag) .name) }}'
          imagePullPolicy: {{ ((.imageOverride).pullPolicy) | default .defaultValues.image.pullPolicy }}
          {{- if .command }}
          command:
            {{- .command | toYaml | nindent 12 -}}
          {{- end }}
          {{- if or .ports .service }}
          ports:
            {{- include "otel-demo.pod.ports" . | nindent 12 }}
          {{- end }}
          env:
            {{- include "otel-demo.pod.env" . | nindent 12 }}
          {{- $mergedResources := dict }}
          {{- if .defaultValues.resources }}
          {{- $mergedResources = .defaultValues.resources | deepCopy }}
          {{- end }}
          {{- if .resources }}
          {{- $mergedResources = mergeOverwrite $mergedResources .resources }}
          {{- end }}
          {{- if or .defaultValues.resources .resources }}
          resources:
            {{- $mergedResources | toYaml | nindent 12 }}
          {{- end }}
          {{- if or .defaultValues.securityContext .securityContext }}
          securityContext:
            {{- .securityContext | default .defaultValues.securityContext | toYaml | nindent 12 }}
          {{- end}}
          {{- if .livenessProbe }}
          livenessProbe:
            {{- .livenessProbe | toYaml | nindent 12 }}
          {{- end }}
          {{- if .volumeMounts }}
          volumeMounts:
            {{- .volumeMounts | toYaml | nindent 12 }}
          {{- end }}
        {{- end }}
      {{- if .initContainers }}
      initContainers:
        {{- tpl (toYaml .initContainers) . | nindent 8 }}
      {{- end}}
      {{- if or .mountedConfigMaps .mountedEmptyDirs .additionalVolumes }}
      volumes:
        {{- range .mountedConfigMaps }}
        - name: {{ .name | lower}}
          configMap:
            {{- if .existingConfigMap }}
            name: {{ tpl .existingConfigMap $ }}
            {{- else }}
            name: {{ $.name }}-{{ .name | lower }}
            {{- end }}
        {{- end }}
        {{- range .mountedEmptyDirs }}
        - name: {{ .name | lower}}
          emptyDir: {}
        {{- end }}
        {{- if .additionalVolumes }}
        {{- tpl (toYaml .additionalVolumes) . | nindent 8 }}
        {{- end }}
      {{- end }}
{{- end }}

{{/*
Demo component Service template
*/}}
{{- define "otel-demo.service" }}
{{- if or .ports .service}}
{{- $service := .service | default dict }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  labels:
    {{- include "otel-demo.labels" . | nindent 4 }}
  {{- with $service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $service.type | default "ClusterIP" }}
  ports:
    {{- if .ports }}
    {{- range .ports }}
    - port: {{ .value }}
      name: {{ .name}}
      targetPort: {{ .value }}
    {{- end }}
    {{- end }}

    {{- if and .service .service.port }}
    - port: {{ .service.port}}
      name: tcp-service
      targetPort: {{ .service.port }}
    {{- if .service.nodePort }}
      nodePort: {{ .service.nodePort }}
    {{- end }}
    {{- end }}

    {{- range $i, $sidecar := .sidecarContainers }}
    {{- if .ports }}
    {{- range .ports }}
    - port: {{ .value }}
      name: {{ .name}}
      targetPort: {{ .value }}
    {{- end }}
    {{- end }}

    {{- if and .service .service.port }}
    - port: {{ .service.port}}
      name: tcp-service-{{ $i }}
      targetPort: {{ .service.port }}
    {{- if .service.nodePort }}
      nodePort: {{ .service.nodePort }}
    {{- end }}
    {{- end }}
    {{- end }}
  selector:
    {{- include "otel-demo.selectorLabels" . | nindent 4 }}
{{- end}}
{{- end}}

{{/*
Demo component ConfigMap template
*/}}
{{- define "otel-demo.configmap" }}
{{- range .mountedConfigMaps }}
{{- if .data }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $.name }}-{{ .name | lower }}
  labels:
        {{- include "otel-demo.labels" $ | nindent 4 }}
data:
  {{- .data | toYaml | nindent 2}}
{{- end}}
{{- end}}
{{- end}}

{{/*
Demo component Ingress template
*/}}
{{- define "otel-demo.ingress" }}
{{- $hasIngress := false}}
{{- if .ingress }}
{{- if .ingress.enabled }}
{{- $hasIngress = true }}
{{- end }}
{{- end }}
{{- $hasServicePorts := false}}
{{- if .service }}
{{- if .service.port }}
{{- $hasServicePorts = true }}
{{- end }}
{{- end }}
{{- if and $hasIngress (or .ports $hasServicePorts) }}
{{- $ingresses := list .ingress }}
{{- if .ingress.additionalIngresses }}
{{-   $ingresses := concat $ingresses .ingress.additionalIngresses -}}
{{- end }}
{{- range $ingresses }}
---
apiVersion: "networking.k8s.io/v1"
kind: Ingress
metadata:
  {{- if .name }}
  name: {{ $.name }}-{{ .name | lower }}
  {{- else }}
  name: {{ $.name }}
  {{- end }}
  labels:
    {{- include "otel-demo.labels" $ | nindent 4 }}
  {{- if .annotations }}
  annotations:
    {{ toYaml .annotations | nindent 4 }}
  {{- end }}
spec:
  {{- if .ingressClassName }}
  ingressClassName: {{ .ingressClassName }}
  {{- end -}}
  {{- if .tls }}
  tls:
    {{- range .tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      {{- with .secretName }}
      secretName: {{ . }}
      {{- end }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $.name }}
                port:
                  number: {{ .port }}
          {{- end }}
    {{- end }}
{{- end}}
{{- end}}
{{- end}}


{{/*
Demo component KEDA ScaledObject template
*/}}
{{- define "otel-demo.scaledobject" -}}
{{- $componentKeda := .keda | default dict -}}
{{- $defaultKeda := .defaultValues.keda | default dict -}}

{{- if or ($defaultKeda.enabled | default false) ($componentKeda.enabled | default false) }}
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ .name }}
  labels:
    {{- include "otel-demo.labels" $ | nindent 4 }}
spec:
  scaleTargetRef:
    name: {{ .name }}
  pollingInterval: {{ $componentKeda.pollingInterval | default $defaultKeda.pollingInterval | default 5 }}
  cooldownPeriod: {{ $componentKeda.cooldownPeriod | default $defaultKeda.cooldownPeriod | default 30 }}
  minReplicaCount: {{ $componentKeda.minReplicas | default $defaultKeda.minReplicas | default 1 }}
  maxReplicaCount: {{ $componentKeda.maxReplicas | default $defaultKeda.maxReplicas | default 5 }}
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: {{ include "otel-demo.name" . }}-{{ .name }}-cpu-utilization
      # This query calculates the average CPU utilization as a percentage of the requested CPU.
      query: |
        sum(rate(container_cpu_usage_seconds_total{container!="", pod=~"^{{ .name }}-[^-]+-[^-]+$"}[1m])) / sum(kube_pod_container_resource_requests{resource="cpu", pod=~"^{{ .name }}-[^-]+-[^-]+$"}) * 100
      threshold: '{{ $componentKeda.targetCPUUtilizationPercentage | default $defaultKeda.targetCPUUtilizationPercentage | default 80 }}'
{{- end }}
{{- end }}

