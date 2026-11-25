// Retired staging endpoint. The tested weekly newsletter is now served by division-newsletter.
Deno.serve(() => new Response(JSON.stringify({error:'This test endpoint is retired.'}),{
 status:410,
 headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store'}
}));