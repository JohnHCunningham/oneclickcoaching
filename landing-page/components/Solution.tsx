'use client'

import { motion } from 'framer-motion'

const solutions = [
  {
    title: 'Instant Analysis',
    description: 'Upload a call transcript or recording. Our AI analyzes it against YOUR methodology (Sandler, MEDDIC, Challenger—you choose) and YOUR scripts in under 30 seconds.',
    icon: '🎯'
  },
  {
    title: 'Tactical Scripts, Not Generic Advice',
    description: 'No fluff. Get specific, word-for-word scripts: "When they say \'send me info,\' respond with..." Reps know exactly what to say on their next call.',
    icon: '📝'
  },
  {
    title: 'Track What Matters',
    description: 'See which methodology principles your team executes well (and which they skip). Identify patterns: Are reps talking too much? Skipping budget discussions? Data tells the story.',
    icon: '📈'
  }
]

const Solution = () => {
  return (
    <section className="section-padding bg-gradient-navy">
      <div className="container-custom">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            AI That Coaches Your Team{' '}
            <span className="bg-gradient-to-r from-teal to-aqua bg-clip-text text-transparent">
              Like You Would
            </span>
            —But for Every Single Call
          </h2>
          <p className="text-xl text-light-muted max-w-3xl mx-auto">
            Upload a sales conversation. Get instant, methodology-specific coaching with exact scripts to use next time.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-8">
          {solutions.map((solution, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.2 }}
              className="card hover:shadow-glow-teal"
            >
              <div className="text-5xl mb-4">{solution.icon}</div>
              <h3 className="text-xl font-bold mb-4 text-teal">{solution.title}</h3>
              <p className="text-light-muted leading-relaxed">{solution.description}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default Solution
