<script lang="ts">
  import { onMount } from "svelte";

  interface Props {
    content: string;
    vaultPath: string | null;
  }

  let { content, vaultPath }: Props = $props();
  let previewEl: HTMLDivElement | undefined = $state();
  let md: any = $state(null);

  onMount(async () => {
    const MarkdownIt = (await import("markdown-it")).default;
    md = new MarkdownIt({
      html: true,
      linkify: true,
      typographer: true,
    });
  });

  let renderedHtml = $derived(md ? md.render(content) : "");
</script>

<div class="markdown-preview" bind:this={previewEl}>
  {@html renderedHtml}
</div>

<style>
  @import "../theme/markdown-preview.css";
</style>
