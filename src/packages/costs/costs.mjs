const links = JSON.parse($.sync`ip --json link`)
  .filter(link => link.ifname.startsWith(argv._[0] || ''))

if (argv['skip-test']) {
  for (const link of links) {
    console.log(`interface "${link.ifname}" {\n  cost 65535;\n};`)
  }
  process.exit(0)
}

const promises = links.map(link => $`ping -q -L -n -i 1 -c 10 -W 10 ff02::1%${link.ifname}`)
const results = await Promise.allSettled(promises)
for (const [i, result] of Object.entries(results)) {
  if (result.status === 'rejected') {
    console.log(`interface "${links[i].ifname}" {\n  cost 65535;\n};`)
    continue
  }
  const loss = /^.+ packets transmitted, .+ received, (?<loss>.+)% packet loss, time .+ms$/m.exec(result.value.stdout)
  const avg = /^rtt min\/avg\/max\/mdev = .+\/(?<avg>.+)\/.+\/.+ ms$/m.exec(result.value.stdout)
  if (!loss || !avg || +loss.groups.loss == 100) {
    console.log(`interface "${links[i].ifname}" {\n  cost 65535;\n};`)
    continue
  }
  const cost = Math.ceil(+avg.groups.avg / (100 - +loss.groups.loss) * 10000)
  console.log(`interface "${links[i].ifname}" {\n  cost ${cost};\n};`)
}
