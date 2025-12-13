'use client'

import { motion } from 'framer-motion'
import { useState } from 'react'

const methodologies = [
  {
    name: 'Sandler Selling System',
    tagline: 'Consultative sales, high-touch B2B',
    description: 'Focus on pain funnel, up-front contracts, and negative reverse selling.',
    points: [
      'Did you set an up-front contract?',
      'How deep did you go in the pain funnel?',
      'Talk/listen ratio (target: 30/70)',
      'Budget discussion before presentation'
    ]
  },
  {
    name: 'MEDDIC/MEDDPICC',
    tagline: 'Enterprise sales, complex deals',
    description: 'Qualify hard. Get coaching on qualification depth.',
    points: [
      'Metrics identified?',
      'Economic buyer confirmed?',
      'Decision criteria clear?',
      'Champion identified?'
    ]
  },
  {
    name: 'Challenger Sale',
    tagline: 'Disruptive solutions',
    description: 'Teach, tailor, take control.',
    points: [
      'Did you teach them something new?',
      'Did you tailor to their specific situation?',
      'Did you take control with constructive tension?'
    ]
  },
  {
    name: 'SPIN Selling',
    tagline: 'Solution selling',
    description: 'Question-based discovery.',
    points: [
      'Situation questions asked?',
      'Problem questions to uncover pain?',
      'Implication questions to build urgency?',
      'Need-payoff questions to create value?'
    ]
  },
  {
    name: 'Gap Selling',
    tagline: 'Problem-solving sales',
    description: 'Problem-centric selling.',
    points: [
      'Current state analysis depth?',
      'Future state vision created?',
      'Gap explicitly stated?',
      'Cost of inaction discussed?'
    ]
  }
]

const Methodologies = () => {
  const [activeIndex, setActiveIndex] = useState(0)

  return (
    <section id="methodologies" className="section-padding bg-navy">
      <div className="container-custom">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-center mb-16"
        >
          <h2 className="text-4xl md:text-5xl font-bold mb-6">
            Your Methodology. Your Scripts.{' '}
            <span className="text-teal">Your Results.</span>
          </h2>
        </motion.div>

        <div className="flex flex-wrap justify-center gap-4 mb-12">
          {methodologies.map((methodology, index) => (
            <button
              key={index}
              onClick={() => setActiveIndex(index)}
              className={`px-6 py-3 rounded-lg font-semibold transition-all ${
                activeIndex === index
                  ? 'bg-gradient-teal text-white shadow-glow-teal'
                  : 'bg-navy-light text-light-muted hover:text-teal'
              }`}
            >
              {methodology.name}
            </button>
          ))}
        </div>

        <motion.div
          key={activeIndex}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="card max-w-3xl mx-auto"
        >
          <div className="text-center mb-6">
            <h3 className="text-3xl font-bold mb-2">{methodologies[activeIndex].name}</h3>
            <p className="text-teal font-semibold">{methodologies[activeIndex].tagline}</p>
          </div>

          <p className="text-xl text-light-muted mb-6 text-center">
            {methodologies[activeIndex].description}
          </p>

          <div className="space-y-3">
            {methodologies[activeIndex].points.map((point, i) => (
              <div key={i} className="flex items-start gap-3 bg-navy/50 p-4 rounded-lg">
                <span className="text-teal text-xl">✓</span>
                <span className="text-light-muted">{point}</span>
              </div>
            ))}
          </div>

          <div className="mt-6 text-center">
            <span className="inline-block bg-teal/20 text-teal px-4 py-2 rounded-full text-sm font-semibold">
              Best for: {methodologies[activeIndex].tagline}
            </span>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

export default Methodologies
